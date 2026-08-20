import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../l10n/app_localizations.dart';

/// 本地通知服务：订阅到期提醒等。
/// 用 flutter_local_notifications（已在依赖，Android 13+ 需运行时请求通知权限）。
///
/// 文案统一走 [AppLocalizations.t]，跟随用户语言切换；通道 ID 保持常量
/// （Android 通道 ID 变更会创建新通道，旧通道残留，故 ID 不应本地化）。
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'subscription_reminder';
  static const String _timerChannelId = 'timer';
  static const String _reminderChannelId = 'timer_reminder';
  static const int _timerNotificationId = 1000;
  /// 计时器晚间提醒通知 ID（与 ongoing 通知区分，可滑动清除）。
  static const int _timerReminderNotificationId = 1001;

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );
    await _plugin.initialize(initSettings);
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    final channel = AndroidNotificationDetails(
      _channelId,
      AppLocalizations.t('notification.subscriptionChannelName'),
      channelDescription: AppLocalizations.t('notification.subscriptionChannelDesc'),
      importance: Importance.high,
      priority: Priority.high,
    );
    final details = NotificationDetails(
      android: channel,
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }

  /// 计时器运行中的常驻通知（不可滑动清除）。
  static Future<void> showTimerRunning({String body = ''}) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _timerChannelId,
        AppLocalizations.t('notification.timerChannelName'),
        channelDescription: AppLocalizations.t('notification.timerChannelDesc'),
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    final fallbackBody = AppLocalizations.t('notification.timerRunningBody');
    await _plugin.show(
      _timerNotificationId,
      AppLocalizations.t('notification.timerRunningTitle'),
      body.isEmpty ? fallbackBody : body,
      details,
    );
  }

  /// 计时器暂停通知。
  static Future<void> showTimerPaused() async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _timerChannelId,
        AppLocalizations.t('notification.timerChannelName'),
        channelDescription: AppLocalizations.t('notification.timerChannelDesc'),
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.show(
      _timerNotificationId,
      AppLocalizations.t('notification.timerPausedTitle'),
      AppLocalizations.t('notification.timerPausedBody'),
      details,
    );
  }

  /// 取消计时器通知（结束/取消计时时调用）。
  static Future<void> cancelTimer() async {
    await _plugin.cancel(_timerNotificationId);
  }

  /// 计时器晚间提醒通知（一次性，可滑动清除）。
  ///
  /// 与 [showTimerRunning] 区分：
  /// - [showTimerRunning] 是 ongoing 通知（不可清除），用于进程保活和实时状态。
  /// - 本通知由 workmanager 周期任务在 19:00–22:30 窗口内触发，提醒用户
  ///   「别忘了停止并保存工时」。优先级为 default，不打扰但可见。
  static Future<void> showTimerReminder({
    required String title,
    required String body,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _reminderChannelId,
        AppLocalizations.t('timerReminderChannelName'),
        channelDescription: AppLocalizations.t('timerReminderChannelDesc'),
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        // 可滑动清除：提醒是一次性的，不需要常驻。
        ongoing: false,
        autoCancel: true,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.show(_timerReminderNotificationId, title, body, details);
  }
}
