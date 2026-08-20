import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/time_log.dart';
import '../models/expense_log.dart';
import '../providers/premium_provider.dart';
import '../providers/timelog_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/premium_guard.dart';
import '../config/app_theme.dart';
import '../utils/currency_format.dart';
import '../utils/tax_estimator.dart';
import '../l10n/app_localizations.dart';

class AnnualReportScreen extends StatefulWidget {
  const AnnualReportScreen({super.key});

  @override
  State<AnnualReportScreen> createState() => _AnnualReportScreenState();
}

class _AnnualReportScreenState extends State<AnnualReportScreen> {
  static const _palette = [
    AppTheme.primary,
    AppTheme.success,
    AppTheme.warning,
    AppTheme.danger,
  ];

  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  // 允许回溯 5 年（IRS 一般要求保留 3 年，给自由职业者留足余量）。
  int get _minYear => DateTime.now().year - 5;
  int get _maxYear => DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t('annualReport'))),
      body: PremiumGuard(
        requiredLevel: PremiumType.annual,
        featureName: AppLocalizations.t('annualTaxReportFeature'),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final timelog = context.watch<TimelogProvider>();
    final expense = context.watch<ExpenseProvider>();

    final year = _selectedYear;
    final yearStart = DateTime(year, 1, 1).millisecondsSinceEpoch;
    final yearEnd = DateTime(year + 1, 1, 1).millisecondsSinceEpoch;
    final yearLogs = timelog.timeLogs.where((t) => t.startTime >= yearStart && t.startTime < yearEnd).toList();
    final yearExpenses = expense.expenses.where((e) => e.expenseDate >= yearStart && e.expenseDate < yearEnd).toList();

    final totalHours = yearLogs.fold<double>(0, (s, t) => s + t.duration);
    // 收入只累计可计费工时（历史数据可能存在非计费但金额未清零的记录）
    final totalIncome = yearLogs.fold<double>(0, (s, t) => s + (t.isBillable ? t.billableAmount : 0));
    final totalExpenses = yearExpenses.fold<double>(0, (s, e) => s + e.amount);
    final deductibleExpenses = yearExpenses.where((e) => e.isTaxDeductible).fold<double>(0, (s, e) => s + e.amount);
    final netIncome = totalIncome - totalExpenses;
    final estTax = TaxEstimator.estimateSelfEmploymentTax(totalIncome, deductibleExpenses, year);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildYearSelector(),
        const SizedBox(height: 16),
        // 免责声明
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.danger.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
          ),
          child: Text(
            AppLocalizations.t('disclaimerPdf'),
            style: const TextStyle(fontSize: 12, color: AppTheme.danger),
          ),
        ),
        const SizedBox(height: 16),
        _buildAnnualMetrics(totalHours, totalIncome, totalExpenses, deductibleExpenses, netIncome, estTax),
        const SizedBox(height: 16),
        // 季度预缴税估算（Form 1040-ES 简化版）：差异化核心功能
        _buildQuarterlyTaxCard(totalIncome, deductibleExpenses),
        const SizedBox(height: 16),
        _buildQuarterlyBreakdown(yearLogs),
        const SizedBox(height: 16),
        _buildMonthlyIncomeTrend(yearLogs),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _exportPdf(context, yearLogs, yearExpenses, year),
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(AppLocalizations.t('exportAnnualTaxPdf'), style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuarterlyTaxCard(double billableIncome, double deductibleExpenses) {
    final q = TaxEstimator.estimateQuarterlyTaxes(billableIncome, deductibleExpenses, _selectedYear);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note_outlined, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.t('quarterlyTaxTitle'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${AppLocalizations.t('perQuarterSuggestion')}: ${CurrencyFormat.money(q.perQuarter)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              '${AppLocalizations.t('selfEmploymentTax')}: ${CurrencyFormat.money(q.seTax)}   '
              '${AppLocalizations.t('federalIncomeTax')}: ${CurrencyFormat.money(q.incomeTax)}',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.t('quarterlyTaxHint'),
              style: const TextStyle(fontSize: 11, color: AppTheme.textDisabled, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  /// 年份选择器：左右箭头切换，范围 [_minYear, _maxYear]。
  Widget _buildYearSelector() {    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _selectedYear > _minYear
                ? () => setState(() => _selectedYear--)
                : null,
            tooltip: AppLocalizations.t1('taxYear', {'year': '${_selectedYear - 1}'}),
          ),
          Text(
            '$_selectedYear',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _selectedYear < _maxYear
                ? () => setState(() => _selectedYear++)
                : null,
            tooltip: AppLocalizations.t1('taxYear', {'year': '${_selectedYear + 1}'}),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnualMetrics(double hours, double income, double expenses, double deductible, double net, double tax) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _metricRow(AppLocalizations.t('totalBillableHours'), '${hours.toStringAsFixed(1)}h', AppTheme.primary),
            const Divider(),
            _metricRow(AppLocalizations.t('totalIncome'), CurrencyFormat.money(income), AppTheme.success),
            const Divider(),
            _metricRow(AppLocalizations.t('totalExpenses'), CurrencyFormat.money(expenses), AppTheme.warning),
            const Divider(),
            _metricRow(AppLocalizations.t('taxDeductibleExpenses'), CurrencyFormat.money(deductible), AppTheme.success),
            const Divider(),
            _metricRow(AppLocalizations.t('netIncome'), CurrencyFormat.money(net), AppTheme.primary),
            const Divider(),
            _metricRow(AppLocalizations.t('estimatedSelfEmploymentTaxPct'), CurrencyFormat.money(tax), AppTheme.danger),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // 季度分布柱状图（按季度收入）
  Widget _buildQuarterlyBreakdown(List<TimeLog> logs) {
    final quarters = List<double>.filled(4, 0);
    for (final t in logs) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.startTime);
      final q = (d.month - 1) ~/ 3;
      quarters[q] += t.isBillable ? t.billableAmount : 0;
    }
    final hasData = logs.isNotEmpty;
    final maxVal = quarters.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.t('quarterlyIncome'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (!hasData)
              SizedBox(
                height: 180,
                child: Center(
                  child: Text(AppLocalizations.t('noDataForThisYear'),
                      style: const TextStyle(fontSize: 14)),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxVal * 1.2 + 1,
                    barGroups: [
                      for (int i = 0; i < 4; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: quarters[i],
                              color: _palette[i],
                              width: 28,
                              borderRadius: const BorderRadius.all(Radius.circular(4)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (int i = 0; i < 4; i++)
                  Text('${AppLocalizations.t1('quarterShort', {'n': '${i + 1}'})}\n${CurrencyFormat.money(quarters[i], decimals: 0)}',
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 月度收入趋势折线图
  Widget _buildMonthlyIncomeTrend(List<TimeLog> logs) {
    final perMonth = List<double>.filled(12, 0);
    for (final t in logs) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.startTime);
      perMonth[d.month - 1] += t.isBillable ? t.billableAmount : 0;
    }
    final hasData = logs.isNotEmpty;
    final maxVal = perMonth.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.t('monthlyIncomeTrend'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (!hasData)
              SizedBox(
                height: 160,
                child: Center(
                  child: Text(AppLocalizations.t('noDataForThisYear'),
                      style: const TextStyle(fontSize: 14)),
                ),
              )
            else
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 11,
                    minY: 0,
                    maxY: maxVal * 1.2 + 1,
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (int m = 0; m < 12; m++) FlSpot(m.toDouble(), perMonth[m]),
                        ],
                        isCurved: true,
                        color: AppTheme.primary,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: AppTheme.primary.withValues(alpha: 0.1)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    List<TimeLog> logs,
    List<ExpenseLog> expenses,
    int year,
  ) async {
    try {
      final bytes = await _buildAnnualPdf(logs, expenses, year);
      await Printing.sharePdf(bytes: bytes, filename: 'annual_tax_summary_$year.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('exportFailed'))),
        );
      }
    }
  }

  Future<Uint8List> _buildAnnualPdf(List<TimeLog> logs, List<ExpenseLog> expenses, int year) async {
    final totalHours = logs.fold<double>(0, (s, t) => s + t.duration);
    final totalIncome = logs.fold<double>(0, (s, t) => s + (t.isBillable ? t.billableAmount : 0));
    final totalExpenses = expenses.fold<double>(0, (s, e) => s + e.amount);
    final deductible = expenses.where((e) => e.isTaxDeductible).fold<double>(0, (s, e) => s + e.amount);
    final net = totalIncome - totalExpenses;
    final estTax = TaxEstimator.estimateSelfEmploymentTax(totalIncome, deductible, year);

    // 季度汇总
    final qIncome = List<double>.filled(4, 0);
    final qExpense = List<double>.filled(4, 0);
    for (final t in logs) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.startTime);
      if (d.year == year) qIncome[(d.month - 1) ~/ 3] += t.isBillable ? t.billableAmount : 0;
    }
    for (final e in expenses) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.expenseDate);
      if (d.year == year) qExpense[(d.month - 1) ~/ 3] += e.amount;
    }

    // 按类目开支
    final byCat = <String, double>{};
    for (final e in expenses) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Text(AppLocalizations.t('annualPdfTitle'),
            style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(AppLocalizations.t1('taxYear', {'year': '$year'}), style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: [AppLocalizations.t('metric'), AppLocalizations.t('value')],
          data: [
            [AppLocalizations.t('totalBillableHours'), '${totalHours.toStringAsFixed(1)}h'],
            [AppLocalizations.t('totalIncome'), CurrencyFormat.money(totalIncome)],
            [AppLocalizations.t('totalExpenses'), CurrencyFormat.money(totalExpenses)],
            [AppLocalizations.t('taxDeductibleExpenses'), CurrencyFormat.money(deductible)],
            [AppLocalizations.t('netIncome'), CurrencyFormat.money(net)],
            [AppLocalizations.t('estimatedSelfEmploymentTaxPct'), CurrencyFormat.money(estTax)],
            // 季度预缴税估算（1040-ES）：SE 税 + 联邦个税按四季分摊
            [
              AppLocalizations.t('perQuarterSuggestion'),
              CurrencyFormat.money(TaxEstimator.estimateQuarterlyTaxes(totalIncome, deductible, year).perQuarter),
            ],
          ],
          headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 20),
        pw.Text(AppLocalizations.t('quarterlySummary'), style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: [AppLocalizations.t('quarter'), AppLocalizations.t('income'), AppLocalizations.t('expenses'), AppLocalizations.t('netIncome')],
          data: [
            for (int i = 0; i < 4; i++)
              [
                AppLocalizations.t1('quarterShort', {'n': '${i + 1}'}),
                CurrencyFormat.money(qIncome[i]),
                CurrencyFormat.money(qExpense[i]),
                CurrencyFormat.money(qIncome[i] - qExpense[i]),
              ],
          ],
          headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 20),
        pw.Text(AppLocalizations.t('expensesByCategory'), style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (byCat.isEmpty)
          pw.Text(AppLocalizations.t('noExpensesPdf'), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
        else
          pw.TableHelper.fromTextArray(
            headers: [AppLocalizations.t('category'), AppLocalizations.t('amount')],
            data: [
              for (final e in byCat.entries) [e.key, CurrencyFormat.money(e.value)],
            ],
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
        pw.SizedBox(height: 24),
        pw.Text(
          AppLocalizations.t('disclaimerPdf'),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          AppLocalizations.t1('generatedBy', {'date': '${DateTime.now().toLocal()}'}),
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
    ));
    return doc.save();
  }
}
