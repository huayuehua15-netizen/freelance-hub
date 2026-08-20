import 'package:flutter/material.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'services/background_task_service.dart';

void main() async {
  // 确保 WidgetsBinding 初始化完成后再调用原生插件。
  // workmanager 必须在 runApp 之前 initialize，否则冷启动回调可能拿不到 dispatcher。
  WidgetsFlutterBinding.ensureInitialized();

  // 生产环境安全断言：API 必须 HTTPS，否则 Android 9+ 明文流量会被静默拦截。
  // assert 仅在 debug 模式生效（开发期立即报警）；release 模式由下面的运行时检查兜底。
  assert(
    !AppConfig.isProd || AppConfig.isHttpsConfigured,
    'Production build must use HTTPS for API_BASE_URL. '
    'Got: ${AppConfig.apiBaseUrl}. '
    'Rebuild with --dart-define=API_BASE_URL=https://your-domain/api/v1',
  );

  // 运行时兜底：release 构建若忘传 HTTPS 地址，这里也能拦住，
  // 渲染友好错误页而非让用户面对满屏"网络错误"或直接闪退。
  if (AppConfig.isProd && !AppConfig.isHttpsConfigured) {
    runApp(const _MisconfiguredApp());
    return;
  }

  await BackgroundTaskService.initialize();
  runApp(const FreelanceHubApp());
}

/// 配置错误时的兜底界面：不依赖任何服务初始化，避免错误雪崩。
/// 仅在 release 构建忘传 HTTPS API 地址时出现，是开发者配置失误的明确信号。
class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
                const SizedBox(height: 24),
                const Text(
                  'Configuration Error',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'This build is missing a secure server address. '
                  'Please contact the developer or update to the latest version.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
