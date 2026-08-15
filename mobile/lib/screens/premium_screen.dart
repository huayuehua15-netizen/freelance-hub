import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/premium_provider.dart';
import '../config/app_theme.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t('upgradeToPremium'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 试用期警告
          if (premium.isTrial) _buildTrialBanner(premium),
          if (premium.isTrial) const SizedBox(height: 16),
          // Free 档
          _buildPlanCard(
            title: AppLocalizations.t('free'),
            price: '\$0',
            subtitle: AppLocalizations.t('foreverFree'),
            features: [
              AppLocalizations.t('feature.free.projects'),
              AppLocalizations.t('feature.free.currentMonthOnly'),
              AppLocalizations.t('feature.timeTrackingWithTags'),
              AppLocalizations.t('feature.expenseTracking'),
              AppLocalizations.t('feature.basicReports'),
            ],
            isSelected: premium.premiumType == PremiumType.free,
            onTap: () => _switchPlan(context, premium, PremiumType.free),
            cta: premium.premiumType == PremiumType.free ? AppLocalizations.t('currentPlan') : AppLocalizations.t('switchToFree'),
          ),
          const SizedBox(height: 16),
          // 月度订阅
          _buildPlanCard(
            title: AppLocalizations.t('planFreelancer'),
            price: '\$4.79/month',
            subtitle: AppLocalizations.t('sevenDayFreeTrial'),
            features: [
              AppLocalizations.t('feature.unlimitedProjects'),
              AppLocalizations.t('feature.timeTrackingWithTags'),
              AppLocalizations.t('feature.taxDeductibleExpenseTracking'),
              AppLocalizations.t('feature.monthlyReportsWithCharts'),
              AppLocalizations.t('feature.localPdfExport'),
              AppLocalizations.t('feature.fullHistoryAccess'),
            ],
            isSelected: premium.premiumType == PremiumType.monthly,
            onTap: () => _switchPlan(context, premium, PremiumType.monthly),
            cta: premium.premiumType == PremiumType.monthly ? AppLocalizations.t('currentPlan') : AppLocalizations.t('startFreeTrial'),
          ),
          const SizedBox(height: 16),
          // 年度订阅
          _buildPlanCard(
            title: AppLocalizations.t('planContractor'),
            price: '\$37.99/year',
            subtitle: AppLocalizations.t('saveBestValue'),
            features: [
              AppLocalizations.t('feature.everythingInFreelancer'),
              AppLocalizations.t('feature.annualTaxSummaryReport'),
              AppLocalizations.t('feature.cloudSyncAcrossDevices'),
              AppLocalizations.t('feature.webDashboardAccess'),
              AppLocalizations.t('feature.batchProjectArchive'),
              AppLocalizations.t('feature.customTaxCategories'),
              AppLocalizations.t('feature.prioritySupport'),
            ],
            isSelected: premium.premiumType == PremiumType.annual,
            highlighted: true,
            onTap: () => _switchPlan(context, premium, PremiumType.annual),
            cta: premium.premiumType == PremiumType.annual ? AppLocalizations.t('currentPlan') : AppLocalizations.t('getAnnualPlan'),
          ),
          const SizedBox(height: 24),
          // 恢复购买
          TextButton(
            onPressed: () async {
              try {
                await premium.restorePurchases();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.t('purchasesRestored'))),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.t1('errors.restoreFailed', {'error': '$e'}))),
                  );
                }
              }
            },
            child: Text(AppLocalizations.t('restorePurchase')),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.t('paymentTerms'),
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (kDebugMode) _buildDemoControls(premium),
        ],
      ),
    );
  }

  Future<void> _switchPlan(BuildContext context, PremiumProvider premium, PremiumType type) async {
    if (type == PremiumType.free) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('manageSubscriptionHint'))),
      );
      return;
    }
    try {
      if (type == PremiumType.monthly) {
        await premium.purchaseMonthly();
      } else {
        await premium.purchaseAnnual();
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('purchaseComplete'))),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t1('errors.purchaseFailed', {'error': '$e'}))),
      );
    }
  }

  Widget _buildTrialBanner(PremiumProvider premium) {
    final daysLeft = premium.trialEndTime != null
        ? ((premium.trialEndTime! - DateTime.now().millisecondsSinceEpoch) / 86400000).ceil()
        : 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${AppLocalizations.t1('daysLeft', {'days': '$daysLeft'})}. ${AppLocalizations.t('upgradeToKeepFeatures')}',
              style: const TextStyle(fontSize: 13, color: AppTheme.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String subtitle,
    required List<String> features,
    required bool isSelected,
    bool highlighted = false,
    required VoidCallback onTap,
    required String cta,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: highlighted ? AppTheme.primary : (isSelected ? AppTheme.success : AppTheme.border),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (highlighted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(AppLocalizations.t('mostPopular'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(price, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 18, color: AppTheme.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: const TextStyle(fontSize: 14))),
                ],
              ),
            )),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isSelected ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: highlighted ? AppTheme.primary : null,
                ),
                child: Text(cta, style: const TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Demo 沙盒控制（仅 debug，正式发布前删除）
  Widget _buildDemoControls(PremiumProvider premium) {
    return Column(
      children: [
        const Divider(),
        Text(AppLocalizations.t('demoControls'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => premium.setPremiumTypeForDemo(PremiumType.free),
              child: Text(AppLocalizations.t('free')),
            ),
            OutlinedButton(
              onPressed: () => premium.setPremiumTypeForDemo(PremiumType.monthly),
              child: Text(AppLocalizations.t('monthly')),
            ),
            OutlinedButton(
              onPressed: () => premium.setPremiumTypeForDemo(PremiumType.annual),
              child: Text(AppLocalizations.t('annual')),
            ),
          ],
        ),
      ],
    );
  }
}
