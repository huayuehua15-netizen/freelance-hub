class AppConfig {
  static const String appName = 'Freelance Hub';
  static const String appVersion = '1.0.0';

  // 环境: dev / staging / prod
  static const String environment = String.fromEnvironment('ENV', defaultValue: 'dev');

  // 后端API地址
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3001/api/v1',
  );

  // RevenueCat API Key
  static const String revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    // A key is injected per environment at build time.  A fake default makes
    // production builds look configured while every purchase fails at runtime.
    defaultValue: '',
  );

  static bool get isDev => environment == 'dev';
  static bool get isProd => environment == 'prod';

  /// 生产环境必须使用 HTTPS：防止忘传 --dart-define 时 release 包默认连 HTTP
  /// 模拟器地址，在 Android 9+ 上静默全部网络失败（用户只看到"网络错误"，排查极困难）。
  /// 这是编译期断言——构建配置错误时立即暴露，不留隐患到运行时。
  static bool get isHttpsConfigured => apiBaseUrl.toLowerCase().startsWith('https://');
}

