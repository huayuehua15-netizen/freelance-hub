/// 货币格式化：金额显示跟随用户在设置里选的 currency（USD/EUR/GBP/CNY/JPY/CAD/AUD）。
///
/// 采用显式符号映射而非 intl 的 NumberFormat：后者在不同 locale 下会改变符号
/// 位置（如 de_DE 把 € 放数字后），且对 CNY 在 en_US 下会渲染成 "CN¥"，破坏紧凑
/// UI 的一致性。金额保留 2 位小数（JPY 无小数）。
class CurrencyFormat {
  /// 全局当前货币，由 AuthProvider 在加载/修改偏好时更新。
  static String current = 'USD';

  static const Map<String, String> _symbols = {
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'CNY': '¥',
    'JPY': '¥',
    'CAD': r'C$',
    'AUD': r'A$',
  };

  /// 当前（或指定）货币的符号，例如 USD → "$"、CNY → "¥"。
  static String symbol([String? code]) => _symbols[code ?? current] ?? r'$';

  /// 格式化金额，如 `money(45.5)` → "$45.50"（跟随 [current]）。
  static String money(double amount, {String? code, int decimals = 2}) {
    final c = code ?? current;
    final d = (c == 'JPY') ? 0 : decimals;
    return '${symbol(c)}${amount.toStringAsFixed(d)}';
  }
}
