import 'package:flutter/foundation.dart';

/// 应用初始化状态通知器。
///
/// 启动时由 [FreelanceHubApp] 持有，初始化流程完成后置 [isInitialized] = true。
/// SplashScreen 监听该状态，确保必要资源（Hive、认证、Premium、通知等）加载
/// 完成后再进入主界面，避免主界面读取未就绪的 Provider 数据导致空指针/错位。
///
/// 设计取舍：
/// - 即便初始化抛错也会被标记完成（见 [FreelanceHubApp._initializeApp] 的
///   finally），保证 splash 不会因初始化失败而永远卡住——降级为本地模式即可。
/// - 与 LocaleProvider 分离，单一职责：只关心"是否就绪"这一布尔信号。
class AppInitNotifier extends ChangeNotifier {
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  void markInitialized() {
    if (_isInitialized) return;
    _isInitialized = true;
    notifyListeners();
  }
}
