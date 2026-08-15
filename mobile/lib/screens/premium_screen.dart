import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/premium_provider.dart';
import '../config/app_theme.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Premium')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 试用期警告
          if (premium.isTrial) _buildTrialBanner(premium),
          if (premium.isTrial) const SizedBox(height: 16),
          // Free 档
          _buildPlanCard(
            title: 'Free',
            price: '\$0',
            subtitle: 'Forever free',
            features: const [
              'Up to 3 client projects',
              'Current month data only',
              'Time tracking with tags',
              'Expense tracking',
              'Basic reports',
            ],
            isSelected: premium.premiumType == PremiumType.free,
            onTap: () => _switchPlan(context, premium, PremiumType.free),
            cta: premium.premiumType == PremiumType.free ? 'Current Plan' : 'Switch to Free',
          ),
          const SizedBox(height: 16),
          // 月度订阅
          _buildPlanCard(
            title: 'Freelancer',
            price: '\$4.79/month',
            subtitle: '7-day free trial',
            features: const [
              'Unlimited client projects',
              'Time tracking with tags',
              'Tax-deductible expense tracking',
              'Monthly reports with charts',
              'Local PDF export',
              'Full history access',
            ],
            isSelected: premium.premiumType == PremiumType.monthly,
            onTap: () => _switchPlan(context, premium, PremiumType.monthly),
            cta: premium.premiumType == PremiumType.monthly ? 'Current Plan' : 'Start Free Trial',
          ),
          const SizedBox(height: 16),
          // 年度订阅
          _buildPlanCard(
            title: 'Contractor',
            price: '\$37.99/year',
            subtitle: 'Save 34% • Best value',
            features: const [
              'Everything in Freelancer',
              'Annual tax summary report',
              'Cloud sync across devices',
              'Web dashboard access',
              'Batch project archive',
              'Custom tax categories',
              'Priority support',
            ],
            isSelected: premium.premiumType == PremiumType.annual,
            highlighted: true,
            onTap: () => _switchPlan(context, premium, PremiumType.annual),
            cta: premium.premiumType == PremiumType.annual ? 'Current Plan' : 'Get Annual Plan',
          ),
          const SizedBox(height: 24),
          // 恢复购买
          TextButton(
            onPressed: () async {
              try {
                await premium.restorePurchases();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Purchases restored.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Unable to restore purchases: $e')),
                  );
                }
              }
            },
            child: const Text('Restore Purchases'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Payment will be charged to your Google Play account. Subscription auto-renews unless canceled at least 24 hours before the end of the current period.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
        const SnackBar(content: Text('You can manage or cancel a subscription in Google Play.')),
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
        const SnackBar(content: Text('Purchase complete. Your access has been updated.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase could not be completed: $e')),
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
              'Your free trial ends in $daysLeft day(s). Upgrade to keep premium features.',
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
                child: const Text('MOST POPULAR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
        const Text('DEMO CONTROLS (Sandbox only)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => premium.setPremiumTypeForDemo(PremiumType.free),
              child: const Text('Free'),
            ),
            OutlinedButton(
              onPressed: () => premium.setPremiumTypeForDemo(PremiumType.monthly),
              child: const Text('Monthly'),
            ),
            OutlinedButton(
              onPressed: () => premium.setPremiumTypeForDemo(PremiumType.annual),
              child: const Text('Annual'),
            ),
          ],
        ),
      ],
    );
  }
}
