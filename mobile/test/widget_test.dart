// Freelance Hub — 基础单元测试。
//
// 原模板测试引用了不存在的 MyApp 类，已替换为对纯工具类的确定性测试，
// 避免依赖 Hive/Flutter 绑定，保证 `flutter test` 可稳定通过。

import 'package:flutter_test/flutter_test.dart';

import 'package:freelance_hub/utils/currency_format.dart';

void main() {
  test('CurrencyFormat 按货币代码输出正确符号', () {
    expect(CurrencyFormat.symbol('USD'), r'$');
    expect(CurrencyFormat.symbol('CNY'), '¥');
    expect(CurrencyFormat.symbol('EUR'), '€');
    expect(CurrencyFormat.symbol('GBP'), '£');
    expect(CurrencyFormat.symbol('unknown'), r'$');
  });

  test('CurrencyFormat.money 保留两位小数', () {
    expect(CurrencyFormat.money(45.5, code: 'USD'), r'$45.50');
    expect(CurrencyFormat.money(1234.5, code: 'USD'), r'$1234.50');
  });

  test('JPY 无小数位', () {
    expect(CurrencyFormat.money(100, code: 'JPY'), '¥100');
  });
}
