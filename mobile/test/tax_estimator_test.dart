import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_hub/utils/tax_estimator.dart';

/// 税务公式是产品核心价值（曾两次出现真 bug：0.153 漏 92.35% 系数、
/// 非计费工时计入收入），必须有测试兜底防回归。
/// 参考值由独立计算脚本验证过（见交接文档 D4 节）。
void main() {
  group('Self-Employment tax (Schedule SE)', () {
    test('50k net earnings in 2026 gives 7064.77', () {
      final tax = TaxEstimator.estimateSelfEmploymentTax(50000, 0, 2026);
      expect(tax, closeTo(7064.77, 0.01));
    });

    test('base below 400 threshold gives 0', () {
      expect(TaxEstimator.estimateSelfEmploymentTax(400, 0, 2026), 0);
      expect(TaxEstimator.estimateSelfEmploymentTax(399.99, 0, 2026), 0);
    });

    test('only tax-deductible expenses reduce the base', () {
      // 100k income: 40k deductible vs 40k non-deductible 结果不同
      final withDeductible = TaxEstimator.estimateSelfEmploymentTax(100000, 40000, 2026);
      final withNonDeductible = TaxEstimator.estimateSelfEmploymentTax(100000, 0, 2026);
      expect(withDeductible, lessThan(withNonDeductible));
      // 精确值：base = 60k × 0.9235 = 55,410 → 55,410 × 0.153 = 8,477.73
      expect(withDeductible, closeTo(8477.73, 0.01));
    });

    test('negative net earnings never produce negative tax', () {
      expect(TaxEstimator.estimateSelfEmploymentTax(100, 5000, 2026), 0);
    });

    test('unknown year falls back to latest table (2026)', () {
      expect(
        TaxEstimator.estimateSelfEmploymentTax(50000, 0, 2027),
        TaxEstimator.estimateSelfEmploymentTax(50000, 0, 2026),
      );
    });
  });

  group('Quarterly estimates (Form 1040-ES)', () {
    test('50k net in 2026 gives per-quarter 2615.22', () {
      final q = TaxEstimator.estimateQuarterlyTaxes(50000, 0, 2026);
      expect(q.seTax, closeTo(7064.77, 0.01));
      expect(q.incomeTax, closeTo(3396.11, 0.01));
      expect(q.total, closeTo(10460.88, 0.01));
      expect(q.perQuarter, closeTo(2615.22, 0.01));
    });

    test('zero income → all zeros', () {
      final q = TaxEstimator.estimateQuarterlyTaxes(0, 0, 2026);
      expect(q.total, 0);
      expect(q.perQuarter, 0);
    });
  });
}
