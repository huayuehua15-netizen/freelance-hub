import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../l10n/app_localizations.dart';
import '../models/user_info.dart';
import '../providers/auth_provider.dart';
import 'api_service.dart';
import 'hive_service.dart';
import 'notification_service.dart';
import 'sync_service.dart';

// kDebugMode 仅用于 callbackDispatcher 的 debugPrint，保留 import。

/// 后台任务服务（workmanager 真正落地）。
///
/// 设计目标：
/// - **不申请 FOREGROUND_SERVICE_SPECIAL_USE 权限**，避免 Google Play 政策审核风险。
/// - 复用 workmanager 周期任务（Android 用 JobScheduler，iOS 用 BGTaskScheduler），
///   在系统调度窗口内执行两类轻量任务：
///   1. [taskBackgroundSync]（每 15 分钟）：登录用户自动同步未推送/未拉取的数据。
///   2. [taskTimerReminder]（每小时检查）：若存在 running 状态的计时且当前处于
///      19:00–22:30（用户本地时间）的提醒窗口，发送一条本地通知，提醒用户
///      别忘了停止并保存工时。
/// - ⚠️ callbackDispatcher 运行在 workmanager 单独启动的 **后台 FlutterEngine**
///   （独立 isolate），主 isolate 的全部初始化（Hive/通知/ApiService 鉴权）
///   在此不可用，必须由 [_ensureBackgroundIsolateReady] 重建。
///
/// 注意：
/// - 周期任务最短间隔为 15 分钟（系统限制），无法做到「精准每小时一次」，
///   `timerReminder` 标称 1h 实际由系统在 15min–1h 之间合并调度。
/// - workmanager 的 inputData 不能在注册后动态更新，所有动态状态都从 Hive 读取。
class BackgroundTaskService {
  /// 周期同步任务名（也作为 callback 内的 switch case key）。
  static const String taskBackgroundSync = 'freelanceHub.backgroundSync';
  static const String taskTimerReminder = 'freelanceHub.timerReminder';

  static const String _tagBackgroundSync = 'backgroundSync';
  static const String _tagTimerReminder = 'timerReminder';

  /// 由 main() 在 runApp 之前调用：注册 callback。
  /// 必须早于 runApp，否则系统在冷启动回调里可能拿不到 dispatcher。
  static Future<void> initialize() async {
    // isInDebugMode 已废弃（0.10.x），不再传；如需调试用 WorkmanagerDebug。
    await Workmanager().initialize(callbackDispatcher);
  }

  /// 注册周期同步任务。仅在登录成功后调用，登出时用 [cancelBackgroundSync] 取消。
  static Future<void> registerBackgroundSync() async {
    await Workmanager().registerPeriodicTask(
      taskBackgroundSync,
      _tagBackgroundSync,
      frequency: const Duration(minutes: 15),
      // 网络可用才执行：无网同步必然失败，没必要消耗电量。
      constraints: Constraints(networkType: NetworkType.connected),
      // 已存在则保留原计划，避免重复 register 抛错。
      // 注意：registerPeriodicTask 用 ExistingPeriodicWorkPolicy（不是 ExistingWorkPolicy）。
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      // 失败后指数退避，避免短时间内连续打后端。
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }

  static Future<void> cancelBackgroundSync() async {
    // 0.10.7 用 cancelByUniqueName（不是 cancelByTaskName）。
    await Workmanager().cancelByUniqueName(taskBackgroundSync);
  }

  /// 注册计时提醒任务。计时启动时调用，停止/取消时用 [cancelTimerReminder] 取消。
  static Future<void> registerTimerReminder() async {
    await Workmanager().registerPeriodicTask(
      taskTimerReminder,
      _tagTimerReminder,
      frequency: const Duration(minutes: 60),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> cancelTimerReminder() async {
    await Workmanager().cancelByUniqueName(taskTimerReminder);
  }

  /// 取消全部后台任务（账号删除/退出登录时调用）。
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}

/// workmanager 顶层回调：必须放在顶层（不能是类方法/闭包），由原生层反射调用。
///
/// 运行在后台 FlutterEngine（独立 isolate）：Hive/通知/鉴权需在此重建。
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await _ensureBackgroundIsolateReady();
      switch (taskName) {
        case BackgroundTaskService.taskBackgroundSync:
          await _runBackgroundSync();
          break;
        case BackgroundTaskService.taskTimerReminder:
          await _runTimerReminder();
          break;
      }
    } catch (e, st) {
      // 不向上抛：workmanager 把异常视为任务失败会指数退避重试，
      // 对「网络偶发失败」的同步任务反而放大电量消耗。
      debugPrint('background task $taskName failed: $e\n$st');
    }
    return true;
  });
}

/// 后台 isolate 一次性重建：Hive（含加密密钥）、通知插件、API 鉴权。
/// workmanager 在独立 FlutterEngine 中执行回调，主 isolate 的初始化全部
/// 不可见；不重建的话 Hive.box() 直接抛异常、通知不显示、API 请求无
/// Authorization 头全部 401 —— 后台任务会静默失败。
bool _bgIsolateReady = false;
Future<void> _ensureBackgroundIsolateReady() async {
  if (_bgIsolateReady) return;
  await HiveService.init();
  await NotificationService.init();
  final auth = AuthProvider();
  await auth.loadFromStorage();
  ApiService().setAuthProvider(auth);
  _bgIsolateReady = true;
}

/// 后台同步：仅当存在登录用户时执行。
/// SyncService 内部对 syncing 状态做了重入保护，重复触发是安全的。
Future<void> _runBackgroundSync() async {
  final userId = await _readActiveUserId();
  if (userId == null) return;
  final syncService = SyncService();
  // 网络不可达时 Dio 会抛出，syncAll 内部已 try/catch 并将状态置为 failed。
  await syncService.syncAll(userId: userId);
}

/// 计时提醒：仅当存在 running 状态的计时 + 当前时间在 19:00–22:30 窗口内时触发。
/// 用 Hive 中持久化的 active_timer 状态判断，避免依赖 Provider 是否已初始化。
Future<void> _runTimerReminder() async {
  final box = HiveService.configBoxInstance;
  final saved = box.get('active_timer');
  if (saved is! Map) return;
  final stateName = saved['state'];
  if (stateName != 'running') return;

  final projectId = saved['projectId'] as String?;
  if (projectId == null || projectId.isEmpty) return;

  // 当前是否已处于提醒窗口（用户本地时间）。workmanager 用设备本地时区调度，
  // DateTime.now() 即用户感知的本地时间，无需做时区换算。
  final now = DateTime.now();
  final minutes = now.hour * 60 + now.minute;
  const windowStart = 19 * 60; // 19:00
  const windowEnd = 22 * 60 + 30; // 22:30
  if (minutes < windowStart || minutes > windowEnd) return;

  // 当日是否已发过提醒（去重）：用 configBox 的简单标记。
  final reminderKey = 'timer_reminder_sent_${now.year}${now.month}${now.day}';
  final alreadySent = box.get(reminderKey);
  if (alreadySent == true) return;

  // 拿项目名拼通知正文；找不到项目就用通用文案。
  final projectBox = HiveService.projectBoxInstance;
  final project = projectBox.get(projectId);
  final projectName = project?.projectName ?? '';

  final body = projectName.isEmpty
      ? AppLocalizations.t('timerReminderTitle')
      : AppLocalizations.t1('timerReminderBody', {'project': projectName});

  await NotificationService.showTimerReminder(
    title: AppLocalizations.t('timerReminderTitle'),
    body: body,
  );
  await box.put(reminderKey, true);
}

/// 从 SharedPreferences 中读取已登录用户的 userId。
///
/// 设计：登录后 [AuthProvider._applySession] / [_persistSession] 会把 UserInfo
/// 序列化为 JSON 写入 `prefs.auth_user`，token 写入 flutter_secure_storage。
/// 这里只读 prefs（轻量、同步可缓存），不依赖 AuthProvider 实例是否已就绪。
///
/// 游客（未登录）的 prefs 中没有 `auth_user` 键，返回 null 跳过同步。
Future<String?> _readActiveUserId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('auth_user');
    if (json == null || json.isEmpty) return null;
    final user = UserInfo.fromJson(jsonDecode(json) as Map<String, dynamic>);
    if (user.userId.isEmpty || user.userId == 'local_user') return null;
    return user.userId;
  } catch (_) {
    return null;
  }
}
