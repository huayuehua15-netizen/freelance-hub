import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'routes.dart';
import 'providers/auth_provider.dart';
import 'providers/premium_provider.dart';
import 'providers/project_provider.dart';
import 'providers/timelog_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/app_init_notifier.dart';
import 'services/background_task_service.dart';
import 'services/hive_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/demo_data_seeder.dart';
import 'services/sync_service.dart';
import 'services/tax_category_sync_service.dart';
import 'utils/error_reporter.dart';

class FreelanceHubApp extends StatefulWidget {
  const FreelanceHubApp({super.key});

  @override
  State<FreelanceHubApp> createState() => _FreelanceHubAppState();
}

class _FreelanceHubAppState extends State<FreelanceHubApp> {
  final AuthProvider _authProvider = AuthProvider();
  final PremiumProvider _premiumProvider = PremiumProvider();
  late final ProjectProvider _projectProvider;
  late final TimelogProvider _timelogProvider;
  final ExpenseProvider _expenseProvider = ExpenseProvider();
  final LocaleProvider _localeProvider = LocaleProvider();
  final SyncService _syncService = SyncService();
  final AppInitNotifier _appInitNotifier = AppInitNotifier();

  @override
  void initState() {
    super.initState();
    _projectProvider = ProjectProvider(_premiumProvider);
    _timelogProvider = TimelogProvider();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 每个步骤独立容错：任何一步失败（如离线时 RevenueCat/后端不可达）
    // 不得中断后续步骤 —— 计时恢复和本地数据加载是离线优先架构的命门。
    Future<void> safeStep(String name, Future<void> Function() step) async {
      try {
        await step();
      } catch (e, st) {
        debugPrint('Init step "$name" failed (degraded): $e');
        // 初始化失败静默降级可以接受，但必须上报——否则线上问题无从发现
        unawaited(ErrorReporter.report(e, st, 'init:$name'));
      }
    }

    await safeStep('hive', () => HiveService.init());
    await safeStep('api', () async => ApiService().setAuthProvider(_authProvider));
    // 登出/删号联动清理 RevenueCat 会话（P1）
    _authProvider.setPremiumProvider(_premiumProvider);
    await safeStep('restoreSession', () => _authProvider.loadFromStorage());
    await safeStep('refreshCurrentUser', () => _authProvider.refreshCurrentUser());
    await safeStep('revenuecat', () => _premiumProvider.initialize(appUserId: _authProvider.user?.userId));
    _syncPremiumFromUser();
    await safeStep('locale', () => _localeProvider.loadLocale());
    // Initialise notifications before restoring a timer so a recovered
    // running session can safely recreate its foreground notification.
    await safeStep('notifications', () => NotificationService.init());
    await safeStep('recoverTimer', () => _timelogProvider.recoverTimer());
    // Demo 数据仅限开发构建：真实新用户（未登录）会被播种 3 个假项目，
    // 占满 Free 3 项目配额且注册后被推到真实云端账号（P0）。
    if (AppConfig.isDev) {
      await safeStep('demoSeed', () => DemoDataSeeder.seedIfEmpty(isLoggedIn: _authProvider.isLoggedIn));
    }
    await safeStep('loadData', () async {
      await _projectProvider.loadProjects();
      await _timelogProvider.loadTimeLogs();
      await _expenseProvider.loadExpenses();
    });
    await safeStep('notificationPermission', () => NotificationService.requestPermission());
    await safeStep('expiryReminder', () => _premiumProvider.checkExpiryReminder());
    // 自定义税务类目云端合并（B5）：已登录用户拉取本人在 Web 端/其它设备
    // 创建的自定义类目（系统默认本地已播种，只合并 isCustom）。任何登录
    // 用户可拉取（list 不限 Annual），失败静默不影响启动。
    if (_authProvider.isLoggedIn) {
      await safeStep('taxCategoryMerge', () => TaxCategorySyncService.pullAndMerge());
    }
    // 注册后台同步任务：仅登录且 Annual 用户需要（云端同步是 Annual 权益，
    // 后端也会拒绝非 Annual 的 batch-upsert，注册了只会永久空转重试）。
    // 用 keep 策略，重复注册不会抛错。
    if (_authProvider.isLoggedIn && _premiumProvider.canCloudSync) {
      await safeStep('backgroundSync', () => BackgroundTaskService.registerBackgroundSync());
    }
    // 如果启动时存在 running 计时，恢复晚间提醒任务。
    if (_timelogProvider.timerState != TimerState.idle) {
      await safeStep('timerReminder', () => BackgroundTaskService.registerTimerReminder());
    }
    _appInitNotifier.markInitialized();
  }

  /// Login/session restoration updates local entitlement state without
  /// manufacturing demo expiry/trial dates.
  void _syncPremiumFromUser() {
    final user = _authProvider.user;
    if (user == null) return;
    _premiumProvider.applyServerEntitlement(
      premiumType: user.premiumType,
      expireTime: user.expireTime,
      trialEndTime: user.trialEndTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _premiumProvider),
        ChangeNotifierProvider.value(value: _projectProvider),
        ChangeNotifierProvider.value(value: _timelogProvider),
        ChangeNotifierProvider.value(value: _expenseProvider),
        ChangeNotifierProvider.value(value: _localeProvider),
        ChangeNotifierProvider.value(value: _syncService),
        ChangeNotifierProvider.value(value: _appInitNotifier),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) => MaterialApp(
          title: 'Freelance Hub',
          debugShowCheckedModeBanner: false,
          locale: localeProvider.locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh')],
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.generateRoute,
        ),
      ),
    );
  }
}
