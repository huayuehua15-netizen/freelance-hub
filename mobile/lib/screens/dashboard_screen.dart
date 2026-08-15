import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timelog_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/project_provider.dart';
import '../l10n/app_localizations.dart';
import '../config/app_theme.dart';
import '../utils/currency_format.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<TimelogProvider>().loadTimeLogs();
          await context.read<ExpenseProvider>().loadExpenses();
          await context.read<ProjectProvider>().loadProjects();
        },
        child: Consumer3<TimelogProvider, ExpenseProvider, ProjectProvider>(
          builder: (context, timelog, expense, project, _) {
            final now = DateTime.now();
            final monthStart = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
            final monthLogs = timelog.timeLogs.where((t) => t.startTime >= monthStart).toList();
            final totalHours = monthLogs.fold<double>(0, (s, t) => s + t.duration);
            final totalIncome = monthLogs.fold<double>(0, (s, t) => s + t.billableAmount);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(totalHours, totalIncome, expense.totalThisMonth),
                const SizedBox(height: 16),
                _buildQuickActions(context),
                const SizedBox(height: 16),
                _buildRecentTimeLogs(context, timelog, project),
                const SizedBox(height: 16),
                _buildRecentExpenses(context, expense),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double hours, double income, double expenses) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This Month', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(AppLocalizations.t('hours'), '${hours.toStringAsFixed(1)}h', AppTheme.primary),
                _buildMetric(AppLocalizations.t('income'), CurrencyFormat.money(income), AppTheme.success),
                _buildMetric(AppLocalizations.t('expenses'), CurrencyFormat.money(expenses), AppTheme.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(Icons.play_arrow, AppLocalizations.t('startTimer'), () {
            Navigator.pushNamed(context, '/timer');
          }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(Icons.receipt_long_outlined, AppLocalizations.t('addExpense'), () {
            Navigator.pushNamed(context, '/expense-form');
          }),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTimeLogs(BuildContext context, TimelogProvider timelog, ProjectProvider project) {
    final recent = timelog.timeLogs.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Time Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/monthly-report'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              _emptyHint('No time logs yet')
            else
              ...recent.map((t) {
                final p = project.getProjectById(t.projectId);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(p?.projectName ?? 'Unknown project'),
                  subtitle: Text(
                    '${t.duration.toStringAsFixed(1)}h${t.tag.isNotEmpty ? ' · ${t.tag}' : ''}',
                  ),
                  trailing: Text(
                    CurrencyFormat.money(t.billableAmount),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/time-log-edit', arguments: t),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentExpenses(BuildContext context, ExpenseProvider expense) {
    final recent = expense.expenses.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Expenses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/expenses'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              _emptyHint('No expenses yet')
            else
              ...recent.map((e) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(e.category),
                  subtitle: e.merchant.isNotEmpty ? Text(e.merchant) : null,
                  trailing: Text(
                    CurrencyFormat.money(e.amount),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
