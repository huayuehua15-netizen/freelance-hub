/// 税务估算工具（与后端 `reportService.js` 公式一致，单一事实来源）。
///
/// 所有返回值均为估算参考，不构成税务建议（页面已带免责声明）。
/// ⚠️ 税率逐年变化：未收录年份回退使用 2026 值，每年 IRS/SSA 公布新
/// 税率后必须在此补表（后端 `constants.js` 的 SE_TAX/FEDERAL_TAX 同步更新）。
class TaxEstimator {
  TaxEstimator._();

  // ── IRS Schedule SE 自雇税 ──────────────────────────────────────
  // 净收益 = 可计费收入 − 可抵扣开支；税基 = 净收益 × 92.35%；
  // 税基 < $400 免缴；社保部分（12.4%）受工资基数上限约束，医保（2.9%）无上限。
  static const double _netEarningsRate = 0.9235;
  static const double _ssRate = 0.124;
  static const double _medicareRate = 0.029;
  static const double _minBase = 400;
  static const Map<int, double> _ssWageBaseByYear = {
    2024: 168600,
    2025: 176100,
    2026: 184500,
  };

  static double estimateSelfEmploymentTax(
    double billableIncome,
    double deductibleExpenses,
    int year,
  ) {
    final netEarnings = (billableIncome - deductibleExpenses).clamp(0.0, double.infinity);
    final base = netEarnings * _netEarningsRate;
    if (base < _minBase) return 0;
    final wageBase = _ssWageBaseByYear[year] ?? _ssWageBaseByYear.values.last;
    return (base < wageBase ? base : wageBase) * _ssRate + base * _medicareRate;
  }

  // ── 联邦个人所得税（单身申报，累进税率）─────────────────────────
  static const Map<int, List<(double, double)>> _bracketsByYear = {
    2025: [(11875.0, .10), (48475.0, .12), (103350.0, .22), (197300.0, .24), (250525.0, .32), (626350.0, .35)],
    2026: [(12400.0, .10), (50400.0, .12), (105700.0, .22), (201775.0, .24), (256225.0, .32), (640600.0, .35)],
  };
  static const double _topBracketRate = .37;

  static double federalIncomeTax(double taxableIncome, int year) {
    final brackets = _bracketsByYear[year] ?? _bracketsByYear.values.last;
    var tax = 0.0;
    var lower = 0.0;
    for (final (upTo, rate) in brackets) {
      if (taxableIncome <= lower) break;
      final span = (taxableIncome < upTo ? taxableIncome : upTo) - lower;
      tax += span * rate;
      lower = upTo;
    }
    if (taxableIncome > lower) tax += (taxableIncome - lower) * _topBracketRate;
    return tax;
  }

  // ── 季度预缴税估算（Form 1040-ES 简化版）────────────────────────
  // AGI 近似 = 净收益 − 自雇税半额 − 标准扣除；每季建议 = 年估算 ÷ 4。
  static const Map<int, double> _stdDeductionByYear = {
    2025: 15000,
    2026: 16100,
  };

  static ({double seTax, double incomeTax, double total, double perQuarter})
      estimateQuarterlyTaxes(double billableIncome, double deductibleExpenses, int year) {
    final netEarnings = (billableIncome - deductibleExpenses).clamp(0.0, double.infinity);
    final seTax = estimateSelfEmploymentTax(billableIncome, deductibleExpenses, year);
    final std = _stdDeductionByYear[year] ?? _stdDeductionByYear.values.last;
    final taxable = (netEarnings - seTax / 2 - std).clamp(0.0, double.infinity);
    final incomeTax = federalIncomeTax(taxable, year);
    final total = seTax + incomeTax;
    return (seTax: seTax, incomeTax: incomeTax, total: total, perQuarter: total / 4);
  }
}
