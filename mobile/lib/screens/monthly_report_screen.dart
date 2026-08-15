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
import '../providers/project_provider.dart';
import '../widgets/premium_guard.dart';
import '../config/app_theme.dart';
import '../utils/currency_format.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const _palette = [
    AppTheme.primary,
    AppTheme.success,
    AppTheme.warning,
    AppTheme.danger,
    Colors.purple,
    Colors.teal,
    Colors.orange,
    Colors.indigo,
    Colors.pink,
    Colors.brown,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note_outlined),
            tooltip: 'Annual Tax Summary',
            onPressed: () => Navigator.pushNamed(context, '/annual-report'),
          ),
        ],
      ),
      body: PremiumGuard(
        requiredLevel: PremiumType.monthly,
        featureName: 'Monthly Report',
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final timelog = context.watch<TimelogProvider>();
    final expense = context.watch<ExpenseProvider>();
    final project = context.watch<ProjectProvider>();

    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1).millisecondsSinceEpoch;
    final nextMonthStart = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1).millisecondsSinceEpoch;
    final monthLogs = timelog.timeLogs.where((t) => t.startTime >= monthStart && t.startTime < nextMonthStart).toList();
    final monthExpenses = expense.expenses.where((e) => e.expenseDate >= monthStart && e.expenseDate < nextMonthStart).toList();

    final totalHours = monthLogs.fold<double>(0, (s, t) => s + t.duration);
    final totalIncome = monthLogs.fold<double>(0, (s, t) => s + t.billableAmount);
    final totalExpenses = monthExpenses.fold<double>(0, (s, e) => s + e.amount);
    final netIncome = totalIncome - totalExpenses;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMonthSelector(),
        const SizedBox(height: 16),
        _buildMetricCard(totalHours, totalIncome, totalExpenses, netIncome),
        const SizedBox(height: 16),
        _buildIncomeTrend(monthLogs),
        const SizedBox(height: 16),
        _buildExpenseByCategory(monthExpenses),
        const SizedBox(height: 16),
        _buildHoursByProject(monthLogs, project),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _exportPdf(context, monthLogs, monthExpenses, project),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Export PDF', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    return Card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
            }),
          ),
          Text(
            '${_months[_selectedMonth.month - 1]} ${_selectedMonth.year}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() {
              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(double hours, double income, double expenses, double net) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metric('Billable Hours', '${hours.toStringAsFixed(1)}h', AppTheme.primary),
                _metric('Income', CurrencyFormat.money(income), AppTheme.success),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metric('Expenses', CurrencyFormat.money(expenses), AppTheme.warning),
                _metric('Net Income', CurrencyFormat.money(net), AppTheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  // 收入趋势折线图（按天）
  Widget _buildIncomeTrend(List logs) {
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final perDay = List<double>.filled(daysInMonth + 1, 0);
    for (final t in logs) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.startTime as int);
      if (d.year == _selectedMonth.year && d.month == _selectedMonth.month) {
        perDay[d.day] += t.billableAmount as double;
      }
    }
    final hasData = logs.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Income Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (!hasData)
              const SizedBox(
                height: 150,
                child: Center(
                  child: Text('No income data for this period',
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
                    minX: 1,
                    maxX: daysInMonth.toDouble(),
                    minY: 0,
                    maxY: (perDay.reduce((a, b) => a > b ? a : b)) * 1.2 + 1,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
                        tooltipRoundedRadius: 8,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              'Day ${spot.x.toInt()}\n${CurrencyFormat.money(spot.y)}',
                              TextStyle(
                                color: AppTheme.success,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (int day = 1; day <= daysInMonth; day++) FlSpot(day.toDouble(), perDay[day]),
                        ],
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: AppTheme.success,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: AppTheme.success.withOpacity(0.1)),
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

  // 开支分类饼图
  Widget _buildExpenseByCategory(List expenses) {
    final byCategory = <String, double>{};
    for (final e in expenses) {
      byCategory[e.category as String] = (byCategory[e.category as String] ?? 0) + (e.amount as double);
    }
    final entries = byCategory.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Expenses by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              const SizedBox(
                height: 150,
                child: Center(
                  child: Text('No expense data for this period',
                      style: TextStyle(fontSize: 14)),
                ),
              )
            else
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        // Touch handled by fl_chart internally for tooltip display
                      },
                    ),
                    sections: [
                      for (int i = 0; i < entries.length; i++)
                        PieChartSectionData(
                          value: entries[i].value,
                          color: _palette[i % _palette.length],
                          radius: 50,
                          title: '${((entries[i].value / entries.map((e) => e.value).reduce((a, b) => a + b)) * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
              ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (int i = 0; i < entries.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, color: _palette[i % _palette.length]),
                        const SizedBox(width: 4),
                        Text('${entries[i].key} (${CurrencyFormat.money(entries[i].value)})',
                            style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 工时按项目分布柱状图
  Widget _buildHoursByProject(List logs, ProjectProvider project) {
    final byProject = <String, double>{};
    for (final t in logs) {
      final pid = t.projectId as String;
      byProject[pid] = (byProject[pid] ?? 0) + (t.duration as double);
    }
    final entries = byProject.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hours by Project', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              const SizedBox(
                height: 150,
                child: Center(
                  child: Text('No time data for this period',
                      style: TextStyle(fontSize: 14)),
                ),
              )
            else
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (entries.map((e) => e.value).reduce((a, b) => a > b ? a : b)) * 1.2 + 1,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
                        tooltipRoundedRadius: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final name = project.getProjectById(entries[groupIndex].key)?.projectName ?? 'Unknown';
                          return BarTooltipItem(
                            '$name\n${rod.toY.toStringAsFixed(1)}h',
                            TextStyle(
                              color: _palette[groupIndex % _palette.length],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    barGroups: [
                      for (int i = 0; i < entries.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: entries[i].value,
                              color: _palette[i % _palette.length],
                              width: 18,
                              borderRadius: const BorderRadius.all(Radius.circular(4)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (int i = 0; i < entries.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, color: _palette[i % _palette.length]),
                        const SizedBox(width: 4),
                        Text(
                          '${project.getProjectById(entries[i].key)?.projectName ?? 'Unknown'} (${entries[i].value.toStringAsFixed(1)}h)',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    List<TimeLog> logs,
    List<ExpenseLog> expenses,
    ProjectProvider project,
  ) async {
    try {
      final bytes = await _buildMonthlyPdf(logs, expenses, project);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'monthly_report_${_selectedMonth.year}_${_selectedMonth.month}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export PDF')),
        );
      }
    }
  }

  Future<Uint8List> _buildMonthlyPdf(
    List<TimeLog> logs,
    List<ExpenseLog> expenses,
    ProjectProvider project,
  ) async {
    final totalHours = logs.fold<double>(0, (s, t) => s + t.duration);
    final totalIncome = logs.fold<double>(0, (s, t) => s + t.billableAmount);
    final totalExpenses = expenses.fold<double>(0, (s, e) => s + e.amount);
    final net = totalIncome - totalExpenses;

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Text('Freelance Hub - Monthly Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('${_months[_selectedMonth.month - 1]} ${_selectedMonth.year}',
            style: pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Metric', 'Value'],
          data: [
            ['Total Hours', '${totalHours.toStringAsFixed(1)}h'],
            ['Total Income', CurrencyFormat.money(totalIncome)],
            ['Total Expenses', CurrencyFormat.money(totalExpenses)],
            ['Net Income', CurrencyFormat.money(net)],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Time Logs', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (logs.isEmpty)
          pw.Text('No time logs', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
        else
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Project', 'Hours', 'Amount', 'Tag'],
            data: [
              for (final t in logs)
                [
                  _fmtDate(t.startTime),
                  project.getProjectById(t.projectId)?.projectName ?? 'Unknown',
                  '${t.duration.toStringAsFixed(1)}h',
                  CurrencyFormat.money(t.billableAmount),
                  t.tag,
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(fontSize: 10),
          ),
        pw.SizedBox(height: 20),
        pw.Text('Expenses', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (expenses.isEmpty)
          pw.Text('No expenses', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
        else
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Category', 'Merchant', 'Amount', 'Deductible'],
            data: [
              for (final e in expenses)
                [
                  _fmtDate(e.expenseDate),
                  e.category,
                  e.merchant,
                  CurrencyFormat.money(e.amount),
                  e.isTaxDeductible ? 'Yes' : 'No',
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(fontSize: 10),
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

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
