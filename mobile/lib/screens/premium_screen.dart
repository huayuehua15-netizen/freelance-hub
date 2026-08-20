import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/premium_provider.dart';
import '../config/app_theme.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  // 商店真实价格（本地货币，含税费规则），null = offerings 不可用，回退参考价
  String? _monthlyPrice;
  String? _annualPrice;
  bool _monthlyHasTrial = false;
  bool _annualHasTrial = false;
  bool _purchasing = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _loadStorePrices();
  }

  Future<void> _loadStorePrices() async {
    final premium = context.read<PremiumProvider>();
    final info = await premium.fetchStoreProducts();
    if (!mounted) return;
    setState(() {
      _monthlyPrice = info.monthlyPrice;
      _annualPrice = info.annualPrice;
      _monthlyHasTrial = info.monthlyHasTrial;
      _annualHasTrial = info.annualHasTrial;
    });
  }

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
            onTap: () => _switchPlan(premium, PremiumType.free),
            cta: premium.premiumType == PremiumType.free ? AppLocalizations.t('currentPlan') : AppLocalizations.t('switchToFree'),
          ),
          const SizedBox(height: 16),
          // 月度订阅：价格优先取商店（本地货币），试用期以商店 IntroductoryOffer 为准
          _buildPlanCard(
            title: AppLocalizations.t('planFreelancer'),
            price: _monthlyPrice ?? '\$4.79/month',
            subtitle: _monthlyHasTrial
                ? AppLocalizations.t('sevenDayFreeTrial')
                : AppLocalizations.t('priceMayVary'),
            features: [
              AppLocalizations.t('feature.unlimitedProjects'),
              AppLocalizations.t('feature.timeTrackingWithTags'),
              AppLocalizations.t('feature.taxDeductibleExpenseTracking'),
              AppLocalizations.t('feature.monthlyReportsWithCharts'),
              AppLocalizations.t('feature.localPdfExport'),
              AppLocalizations.t('feature.fullHistoryAccess'),
            ],
            isSelected: premium.premiumType == PremiumType.monthly,
            onTap: _purchasing ? null : () => _switchPlan(premium, PremiumType.monthly),
            cta: premium.premiumType == PremiumType.monthly ? AppLocalizations.t('currentPlan') : AppLocalizations.t('startFreeTrial'),
          ),
          const SizedBox(height: 16),
          // 年度订阅
          _buildPlanCard(
            title: AppLocalizations.t('planContractor'),
            price: _annualPrice ?? '\$37.99/year',
            subtitle: _annualHasTrial
                ? AppLocalizations.t('sevenDayFreeTrial')
                : AppLocalizations.t('saveBestValue'),
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
            onTap: _purchasing ? null : () => _switchPlan(premium, PremiumType.annual),
            cta: premium.premiumType == PremiumType.annual ? AppLocalizations.t('currentPlan') : AppLocalizations.t('getAnnualPlan'),
          ),
          const SizedBox(height: 24),
          // 恢复购买
          TextButton(
            onPressed: _restoring ? null : () => _restorePurchases(premium),
            child: _restoring
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppLocalizations.t('restorePurchase')),
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

  Future<void> _restorePurchases(PremiumProvider premium) async {
    setState(() => _restoring = true);
    try {
      await premium.restorePurchases();
      if (!mounted) return;
      // 如实反馈：恢复后仍是 free 档说明本账号没有可恢复的订阅
      final msg = premium.isPremium
          ? AppLocalizations.t('purchasesRestored')
          : AppLocalizations.t('noPurchasesToRestore');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t1('errors.restoreFailed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _switchPlan(PremiumProvider premium, PremiumType type) async {
    if (type == PremiumType.free) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('manageSubscriptionHint'))),
      );
      return;
    }
    // 购买进行中锁定按钮：结算弹窗期间双击会重复发起购买
    setState(() => _purchasing = true);
    try {
      if (type == PremiumType.monthly) {
        await premium.purchaseMonthly();
      } else {
        await premium.purchaseAnnual();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('purchaseComplete'))),
      );
      Navigator.pop(context);
    } on PurchaseCanceledException {
      // 用户主动取消购买（关闭 Google Play 结算弹窗）：
      // 静默友好提示，不当作错误，不打扰用户。
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('purchaseCanceled'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t1('errors.purchaseFailed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Widget _buildTrialBanner(PremiumProvider premium) {
    final daysLeft = premium.trialEndTime != null
        ? ((premium.trialEndTime! - DateTime.now().millisecondsSinceEpoch) / 86400000).ceil()
        : 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
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
    required VoidCallback? onTap,
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
