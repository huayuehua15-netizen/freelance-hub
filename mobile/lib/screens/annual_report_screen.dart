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

class AnnualReportScreen extends StatelessWidget {
  const AnnualReportScreen({super.key});

  static const _palette = [
    AppTheme.primary,
    AppTheme.success,
    AppTheme.warning,
    AppTheme.danger,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Annual Tax Summary')),
      body: PremiumGuard(
        requiredLevel: PremiumType.annual,
        featureName: 'Annual Tax Report',
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final timelog = context.watch<TimelogProvider>();
    final expense = context.watch<ExpenseProvider>();

    final year = DateTime.now().year;
    final yearStart = DateTime(year, 1, 1).millisecondsSinceEpoch;
    final yearEnd = DateTime(year + 1, 1, 1).millisecondsSinceEpoch;
    final yearLogs = timelog.timeLogs.where((t) => t.startTime >= yearStart && t.startTime < yearEnd).toList();
    final yearExpenses = expense.expenses.where((e) => e.expenseDate >= yearStart && e.expenseDate < yearEnd).toList();

    final totalHours = yearLogs.fold<double>(0, (s, t) => s + t.duration);
    final totalIncome = yearLogs.fold<double>(0, (s, t) => s + t.billableAmount);
    final totalExpenses = yearExpenses.fold<double>(0, (s, e) => s + e.amount);
    final deductibleExpenses = yearExpenses.where((e) => e.isTaxDeductible).fold<double>(0, (s, e) => s + e.amount);
    final netIncome = totalIncome - totalExpenses;
    final estTax = netIncome * 0.153;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 免责声明
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.danger.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
          ),
          child: const Text(
            'DISCLAIMER: This report is for record-keeping purposes only and does not constitute tax advice. Consult a certified tax professional.',
            style: TextStyle(fontSize: 12, color: AppTheme.danger),
          ),
        ),
        const SizedBox(height: 16),
        _buildAnnualMetrics(totalHours, totalIncome, totalExpenses, deductibleExpenses, netIncome, estTax),
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
            label: const Text('Export Annual Tax Summary PDF', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildAnnualMetrics(double hours, double income, double expenses, double deductible, double net, double tax) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _metricRow('Total Billable Hours', '${hours.toStringAsFixed(1)}h', AppTheme.primary),
            const Divider(),
            _metricRow('Total Income', CurrencyFormat.money(income), AppTheme.success),
            const Divider(),
            _metricRow('Total Expenses', CurrencyFormat.money(expenses), AppTheme.warning),
            const Divider(),
            _metricRow('Tax Deductible Expenses', CurrencyFormat.money(deductible), AppTheme.success),
            const Divider(),
            _metricRow('Net Income', CurrencyFormat.money(net), AppTheme.primary),
            const Divider(),
            _metricRow('Est. Self-Employment Tax (15.3%)', CurrencyFormat.money(tax), AppTheme.danger),
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
      quarters[q] += t.billableAmount;
    }
    final hasData = logs.isNotEmpty;
    final maxVal = quarters.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quarterly Income', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (!hasData)
              const SizedBox(
                height: 180,
                child: Center(
                  child: Text('No data for this year',
                      style: TextStyle(fontSize: 14)),
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
                  Text('Q${i + 1}\n${CurrencyFormat.money(quarters[i], decimals: 0)}',
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
      perMonth[d.month - 1] += t.billableAmount;
    }
    final hasData = logs.isNotEmpty;
    final maxVal = perMonth.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Income Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (!hasData)
              const SizedBox(
                height: 160,
                child: Center(
                  child: Text('No data for this year',
                      style: TextStyle(fontSize: 14)),
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
                        belowBarData: BarAreaData(show: true, color: AppTheme.primary.withOpacity(0.1)),
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
          const SnackBar(content: Text('Failed to export PDF')),
        );
      }
    }
  }

  Future<Uint8List> _buildAnnualPdf(List<TimeLog> logs, List<ExpenseLog> expenses, int year) async {
    final totalHours = logs.fold<double>(0, (s, t) => s + t.duration);
    final totalIncome = logs.fold<double>(0, (s, t) => s + t.billableAmount);
    final totalExpenses = expenses.fold<double>(0, (s, e) => s + e.amount);
    final deductible = expenses.where((e) => e.isTaxDeductible).fold<double>(0, (s, e) => s + e.amount);
    final net = totalIncome - totalExpenses;
    final estTax = net * 0.153;

    // 季度汇总
    final qIncome = List<double>.filled(4, 0);
    final qExpense = List<double>.filled(4, 0);
    for (final t in logs) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.startTime);
      if (d.year == year) qIncome[(d.month - 1) ~/ 3] += t.billableAmount;
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
        pw.Text('Freelance Hub - Annual Tax Summary',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Tax Year $year', style: pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Metric', 'Value'],
          data: [
            ['Total Billable Hours', '${totalHours.toStringAsFixed(1)}h'],
            ['Total Income', CurrencyFormat.money(totalIncome)],
            ['Total Expenses', CurrencyFormat.money(totalExpenses)],
            ['Tax Deductible Expenses', CurrencyFormat.money(deductible)],
            ['Net Income', CurrencyFormat.money(net)],
            ['Est. Self-Employment Tax (15.3%)', CurrencyFormat.money(estTax)],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Quarterly Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Quarter', 'Income', 'Expenses', 'Net'],
          data: [
            for (int i = 0; i < 4; i++)
              [
                'Q${i + 1}',
                CurrencyFormat.money(qIncome[i]),
                CurrencyFormat.money(qExpense[i]),
                CurrencyFormat.money(qIncome[i] - qExpense[i]),
              ],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Expenses by Category', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (byCat.isEmpty)
          pw.Text('No expenses', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
        else
          pw.TableHelper.fromTextArray(
            headers: ['Category', 'Amount'],
            data: [
              for (final e in byCat.entries) [e.key, CurrencyFormat.money(e.value)],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(fontSize: 10),
          ),
        pw.SizedBox(height: 24),
        pw.Text(
          'DISCLAIMER: This report is for record-keeping purposes only and does not constitute tax advice. Consult a certified tax professional.',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Generated by Freelance Hub · ${DateTime.now().toLocal()}',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
    ));
    return doc.save();
  }
}
