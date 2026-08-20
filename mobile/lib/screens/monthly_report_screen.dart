import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
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
import '../l10n/app_localizations.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // 月份名按当前 locale 渲染：之前硬编码英文数组，中文用户看到 "January 2026" 与界面语言不一致。
  String _formatMonthYear(DateTime date) {
    final locale = AppLocalizations.current.languageCode;
    // intl 的本地化数据需通过 flutter_localications 加载；这里传入 locale 名称，
    // 若该 locale 未初始化则 DateFormat 会回退到默认英文，保证不抛错。
    final monthName = DateFormat.MMMM(locale).format(date);
    return '$monthName ${date.year}';
  }

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
        title: Text(AppLocalizations.t('monthlyReport')),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note_outlined),
            tooltip: AppLocalizations.t('annualReport'),
            onPressed: () => Navigator.pushNamed(context, '/annual-report'),
          ),
        ],
      ),
      body: PremiumGuard(
        requiredLevel: PremiumType.monthly,
        featureName: AppLocalizations.t('monthlyReport'),
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
    // 收入只累计可计费工时（历史数据可能存在非计费但金额未清零的记录）
    final totalIncome = monthLogs.fold<double>(0, (s, t) => s + (t.isBillable ? t.billableAmount : 0));
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
            label: Text(AppLocalizations.t('exportPdf'), style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    // 未来月份无数据可看：右箭头到达当月后禁用（年报年份选择器同策略）
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;
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
            _formatMonthYear(_selectedMonth),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentMonth
                ? null
                : () => setState(() {
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
                _metric(AppLocalizations.t('billableHours'), '${hours.toStringAsFixed(1)}h', AppTheme.primary),
                _metric(AppLocalizations.t('income'), CurrencyFormat.money(income), AppTheme.success),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metric(AppLocalizations.t('expenses'), CurrencyFormat.money(expenses), AppTheme.warning),
                _metric(AppLocalizations.t('netIncome'), CurrencyFormat.money(net), AppTheme.primary),
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
        perDay[d.day] += (t.isBillable as bool? ?? true) ? t.billableAmount as double : 0.0;
      }
    }
    final hasData = logs.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.t('incomeTrend'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (!hasData)
              SizedBox(
                height: 150,
                child: Center(
                  child: Text(AppLocalizations.t('noIncomeDataForPeriod'),
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
                              '${AppLocalizations.t1('dayTooltip', {'n': '${spot.x.toInt()}'})}\n${CurrencyFormat.money(spot.y)}',
                              const TextStyle(
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
                        belowBarData: BarAreaData(show: true, color: AppTheme.success.withValues(alpha: 0.1)),
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
            Text(AppLocalizations.t('expensesByCategory'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              SizedBox(
                height: 150,
                child: Center(
                  child: Text(AppLocalizations.t('noExpenseDataForPeriod'),
                      style: const TextStyle(fontSize: 14)),
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
            Text(AppLocalizations.t('hoursByProject'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              SizedBox(
                height: 150,
                child: Center(
                  child: Text(AppLocalizations.t('noTimeDataForPeriod'),
                      style: const TextStyle(fontSize: 14)),
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
                          final name = project.getProjectById(entries[groupIndex].key)?.projectName ?? AppLocalizations.t('unknown');
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
                          '${project.getProjectById(entries[i].key)?.projectName ?? AppLocalizations.t('unknown')} (${entries[i].value.toStringAsFixed(1)}h)',
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
          SnackBar(content: Text(AppLocalizations.t('exportFailed'))),
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
    final totalIncome = logs.fold<double>(0, (s, t) => s + (t.isBillable ? t.billableAmount : 0));
    final totalExpenses = expenses.fold<double>(0, (s, e) => s + e.amount);
    final net = totalIncome - totalExpenses;

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Text(AppLocalizations.t('monthlyPdfTitle'),
            style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(_formatMonthYear(_selectedMonth),
            style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: [AppLocalizations.t('metric'), AppLocalizations.t('value')],
          data: [
            [AppLocalizations.t('totalHours'), '${totalHours.toStringAsFixed(1)}h'],
            [AppLocalizations.t('totalIncome'), CurrencyFormat.money(totalIncome)],
            [AppLocalizations.t('totalExpenses'), CurrencyFormat.money(totalExpenses)],
            [AppLocalizations.t('netIncome'), CurrencyFormat.money(net)],
          ],
          headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 20),
        pw.Text(AppLocalizations.t('timeLogs'), style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (logs.isEmpty)
          pw.Text(AppLocalizations.t('noTimeLogsPdf'), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
        else
          pw.TableHelper.fromTextArray(
            headers: [AppLocalizations.t('date'), AppLocalizations.t('project'), AppLocalizations.t('hours'), AppLocalizations.t('amount'), AppLocalizations.t('tag')],
            data: [
              for (final t in logs)
                [
                  _fmtDate(t.startTime),
                  project.getProjectById(t.projectId)?.projectName ?? AppLocalizations.t('unknown'),
                  '${t.duration.toStringAsFixed(1)}h',
                  CurrencyFormat.money(t.billableAmount),
                  t.tag,
                ],
            ],
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
        pw.SizedBox(height: 20),
        pw.Text(AppLocalizations.t('expenses'), style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (expenses.isEmpty)
          pw.Text(AppLocalizations.t('noExpensesPdf'), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
        else
          pw.TableHelper.fromTextArray(
            headers: [AppLocalizations.t('date'), AppLocalizations.t('category'), AppLocalizations.t('merchant'), AppLocalizations.t('amount'), AppLocalizations.t('deductible')],
            data: [
              for (final e in expenses)
                [
                  _fmtDate(e.expenseDate),
                  e.category,
                  e.merchant,
                  CurrencyFormat.money(e.amount),
                  e.isTaxDeductible ? AppLocalizations.t('yes') : AppLocalizations.t('no'),
                ],
            ],
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
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

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
