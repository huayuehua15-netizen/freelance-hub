import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_init_notifier.dart';
import '../providers/auth_provider.dart';

/// 启动页。
///
/// 等待 [AppInitNotifier.isInitialized] 变为 true（Hive、认证、Premium、
/// 通知等关键资源就绪）后再进入主界面，避免主界面读取未就绪的 Provider
/// 数据导致空指针/错位。同时保留最小展示时长（800ms），避免闪屏过快
/// 造成视觉抖动。
///
/// 即使初始化失败（降级为本地模式），[AppInitNotifier] 也会被标记完成，
/// splash 不会卡死。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// 最小展示时长：保证品牌曝光，避免初始化过快时画面一闪而过。
  static const Duration _minDisplayDuration = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _waitAndNavigate();
  }

  Future<void> _waitAndNavigate() async {
    // 并行等待：最小展示时长 + 应用初始化完成。
    // 初始化状态通过 provider 监听，这里用轮询兜底（provider 重建时
    // build 会重新触发，但 _waitAndNavigate 只在 initState 调用一次，
    // 故用轮询确保捕获后续状态变更）。
    final initNotifier = context.read<AppInitNotifier>();
    final stopwatch = Stopwatch()..start();

    while (!initNotifier.isInitialized && stopwatch.elapsed < const Duration(seconds: 10)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 保证最小展示时长。
    final elapsed = stopwatch.elapsed;
    if (elapsed < _minDisplayDuration) {
      await Future.delayed(_minDisplayDuration - elapsed);
    }

    if (!mounted) return;
    final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
    Navigator.pushReplacementNamed(context, isLoggedIn ? '/dashboard' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.timer_outlined, size: 48, color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.t('appTitle'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.t('splashTagline'),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
