import 'package:flutter/material.dart';

/// BuildContext 便捷扩展，消除重复的 SnackBar 样板代码。
///
/// 现状：项目中有 15+ 处 `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(...)))`。
/// 本扩展提供一行调用，且自动区分成功/错误视觉风格（错误用红色背景）。
///
/// 用法：
/// ```dart
/// context.showSuccess(AppLocalizations.t('timeLogSaved'));
/// context.showError(AppLocalizations.t('exportFailed'));
/// context.showError(msg, actionLabel: 'Retry', onAction: () => retry());
/// ```
///
/// 注意：调用前无需手动检查 `mounted`——扩展内部通过 [ScaffoldMessenger] 安全
/// 访问，即使 Scaffold 已被 dispose 也不会崩溃（Messenger 是 app 级单例）。
/// 但如果 context 对应的 Element 已卸载，调用是无副作用的空操作。
extension ContextSnackBarX on BuildContext {
  /// 显示成功提示（默认主题色背景）。
  void showSuccess(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 显示错误提示（红色背景，可选操作按钮）。
  ///
  /// [actionLabel] + [onAction] 同时提供时显示操作按钮（如「重试」）。
  void showError(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(this).colorScheme.errorContainer,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction,
                textColor: Theme.of(this).colorScheme.onErrorContainer,
              )
            : null,
      ),
    );
  }
}
