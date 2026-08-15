import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'routes.dart';
import 'providers/auth_provider.dart';
import 'providers/premium_provider.dart';
import 'providers/project_provider.dart';
import 'providers/timelog_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/locale_provider.dart';
import 'services/hive_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/demo_data_seeder.dart';
import 'services/sync_service.dart';

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

  @override
  void initState() {
    super.initState();
    _projectProvider = ProjectProvider(_premiumProvider);
    _timelogProvider = TimelogProvider();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await HiveService.init();
      ApiService().setAuthProvider(_authProvider);
      await _authProvider.loadFromStorage();
      await _authProvider.refreshCurrentUser();
      await _premiumProvider.initialize(appUserId: _authProvider.user?.userId);
      _syncPremiumFromUser();
      await _localeProvider.loadLocale();
      // Initialise notifications before restoring a timer so a recovered
      // running session can safely recreate its foreground notification.
      await NotificationService.init();
      await _timelogProvider.recoverTimer();
      await DemoDataSeeder.seedIfEmpty();
      await _projectProvider.loadProjects();
      await _timelogProvider.loadTimeLogs();
      await _expenseProvider.loadExpenses();
      await NotificationService.requestPermission();
      await _premiumProvider.checkExpiryReminder();
    } catch (e) {
      // 初始化失败不阻断启动，降级为本地模式
    }
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
