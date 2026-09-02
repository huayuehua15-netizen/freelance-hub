import 'package:sentry/sentry.dart';

/// 崩溃上报统一入口。
///
/// DSN 通过构建期 `--dart-define=SENTRY_DSN=...` 注入；未注入（或为空）时
/// 上报为 no-op，应用行为与无上报版本完全一致。业务代码不感知 DSN 配置，
/// 只管调用 [report]——初始化失败的步骤、后台同步失败、同步冲突等
/// 静默降级的异常都应上报，否则付费应用线上出问题只能靠用户反馈发现。
class ErrorReporter {
  ErrorReporter._();

  static bool _enabled = false;

  /// main() 中 Sentry 初始化成功后调用；DSN 为空时不调用。
  static void configure() => _enabled = true;

  static Future<void> report(
    dynamic error, [
    StackTrace? stackTrace,
    String? context,
  ]) async {
    if (!_enabled) return;
    try {
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (context != null) scope.setTag('context', context);
        },
      );
    } catch (_) {
      // 上报本身失败绝不影响业务流程
    }
  }
}
