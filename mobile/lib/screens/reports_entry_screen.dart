import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 报表入口页：作为底部导航第 4 个 Tab，聚合月报 / 年报 / 导出 PDF 三个入口。
/// 此前报表 Tab 直接进月报，年报只能从 AppBar action 进，导出散落各处；
/// 改为入口页后功能分区清晰，符合海外竞品（如 QuickBooks、Wave）的报表中心模式。
class ReportsEntryScreen extends StatelessWidget {
  const ReportsEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('reports')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportCard(
            icon: Icons.calendar_month,
            color: AppTheme.primary,
            title: AppLocalizations.t('monthlyReport'),
            subtitle: AppLocalizations.t('monthlyReportHint'),
            onTap: () => Navigator.pushNamed(context, '/monthly-report'),
          ),
          const SizedBox(height: 12),
          _ReportCard(
            icon: Icons.account_balance,
            color: AppTheme.success,
            title: AppLocalizations.t('annualReport'),
            subtitle: AppLocalizations.t('annualReportHint'),
            onTap: () => Navigator.pushNamed(context, '/annual-report'),
          ),
          const SizedBox(height: 12),
          _ReportCard(
            icon: Icons.picture_as_pdf,
            color: AppTheme.warning,
            title: AppLocalizations.t('exportAnnualTaxPdf'),
            subtitle: AppLocalizations.t('exportPdfHint'),
            onTap: () => Navigator.pushNamed(context, '/annual-report'),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}
