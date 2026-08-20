import 'package:flutter/material.dart';

/// 页面级 Loading 占位组件。
///
/// 用法：`if (provider.loading) return const LoadingState();`
///
/// 替代各页面中重复的 `Center(child: CircularProgressIndicator())`。
/// 支持可选 [message] 显示加载文案（如「正在同步...」）。
class LoadingState extends StatelessWidget {
  /// 可选的加载文案，显示在指示器下方。
  final String? message;

  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 页面级 Error 占位组件，带重试按钮。
///
/// 用法：
/// ```dart
/// if (provider.error) return ErrorState(
///   message: AppLocalizations.t('loadFailed'),
///   onRetry: () => provider.reload(),
/// );
/// ```
///
/// 替代各页面中不一致的错误处理（有的用 SnackBar、有的用 Center+Text）。
/// 提供 icon + message + retry 按钮的标准三段式布局。
class ErrorState extends StatelessWidget {
  /// 错误描述文案。
  final String message;

  /// 重试回调。为 null 时不显示重试按钮（适用于不可恢复的错误）。
  final VoidCallback? onRetry;

  /// 重试按钮文案，默认用 Material 默认。
  final String? retryLabel;

  /// 自定义图标，默认 [Icons.error_outline]。
  final IconData icon;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retryLabel ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 按钮内 Loading 指示器。
///
/// 用法：在按钮的 child 中：
/// ```dart
/// child: _saving ? const ButtonLoadingIndicator() : Text('Save'),
/// ```
///
/// 替代各页面不一致的按钮 loading 样式：
/// - projects_screen / project_detail_screen: `SizedBox(width:20, height:20, child: CircularProgressIndicator(strokeWidth: 2))`
/// - login_screen: `CircularProgressIndicator(color: Colors.white)`（无尺寸约束）
///
/// 统一为 20x20、strokeWidth 2、颜色跟随按钮前景色（白色）。
class ButtonLoadingIndicator extends StatelessWidget {
  /// 指示器颜色，默认白色（配合 ElevatedButton/FilledButton 的深色背景）。
  final Color? color;

  const ButtonLoadingIndicator({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? Colors.white,
      ),
    );
  }
}
