import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/app_config.dart';
import '../services/notification_service.dart';

enum PremiumType { free, monthly, annual }

class PremiumProvider extends ChangeNotifier {
  static const _monthlyEntitlement = 'monthly_premium';
  static const _annualEntitlement = 'annual_pro';
  PremiumType _premiumType = PremiumType.free;
  bool _isPremium = false;
  bool _isAnnual = false;
  int? _expireTime;
  bool _isTrial = false;
  int? _trialEndTime;
  bool _isInitialized = false;
  bool _purchasesConfigured = false;

  PremiumType get premiumType => _premiumType;
  bool get isPremium => _isPremium;
  bool get isFree => !_isPremium;
  bool get isAnnual => _isAnnual;
  int? get expireTime => _expireTime;
  bool get isTrial => _isTrial;
  int? get trialEndTime => _trialEndTime;
  bool get isInitialized => _isInitialized;
  bool get isRevenueCatConfigured => _purchasesConfigured;

  // 权限判断
  bool get canUseUnlimitedProjects => _isPremium;
  bool get canUseMonthlyReport => _isPremium;
  bool get canUseAnnualReport => _isAnnual;
  bool get canExportPdf => _isPremium;
  bool get canCloudSync => _isAnnual;
  bool get canAccessWeb => _isAnnual;
  bool get canBatchArchive => _isAnnual;
  bool get canCustomTaxCategory => _isAnnual;

  Future<void> initialize({String? appUserId}) async {
    if (_isInitialized) {
      if (appUserId != null && appUserId.isNotEmpty) await identifyUser(appUserId);
      return;
    }
    _isInitialized = true;

    // Local/demo mode intentionally remains usable when a RevenueCat key has
    // not been supplied.  Purchase actions then clearly report configuration
    // instead of pretending that a subscription succeeded.
    if (AppConfig.revenueCatApiKey.trim().isEmpty) {
      notifyListeners();
      return;
    }

    final configuration = PurchasesConfiguration(AppConfig.revenueCatApiKey)
      ..appUserID = appUserId;
    await Purchases.configure(configuration);
    Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);
    _purchasesConfigured = true;
    await _refreshCustomerInfo();
    notifyListeners();
  }

  void _handleCustomerInfoUpdate(CustomerInfo info) {
    _updateFromEntitlements(info.entitlements);
    notifyListeners();
  }

  void _updateFromEntitlements(EntitlementInfos entitlements) {
    final annual = entitlements.active[_annualEntitlement];
    final monthly = entitlements.active[_monthlyEntitlement];
    final active = annual ?? monthly;
    final type = annual != null
        ? PremiumType.annual
        : monthly != null
            ? PremiumType.monthly
            : PremiumType.free;
    _applyPremiumState(
      type,
      expireTime: _parseExpiry(active?.expirationDate),
      isTrial: active?.periodType == PeriodType.trial,
    );
  }

  Future<void> purchaseMonthly() async {
    final package = await _packageFor((offering) => offering.monthly);
    final info = await Purchases.purchasePackage(package);
    _handleCustomerInfoUpdate(info);
  }

  Future<void> purchaseAnnual() async {
    final package = await _packageFor((offering) => offering.annual);
    final info = await Purchases.purchasePackage(package);
    _handleCustomerInfoUpdate(info);
  }

  Future<void> restorePurchases() async {
    _requirePurchasesConfiguration();
    final info = await Purchases.restorePurchases();
    _handleCustomerInfoUpdate(info);
  }

  Future<void> _refreshCustomerInfo() async {
    if (!_purchasesConfigured) return;
    final info = await Purchases.getCustomerInfo();
    _handleCustomerInfoUpdate(info);
  }

  Future<void> identifyUser(String userId) async {
    if (userId.isEmpty) return;
    if (!_isInitialized) {
      await initialize(appUserId: userId);
      return;
    }
    if (!_purchasesConfigured) return;
    final result = await Purchases.logIn(userId);
    _handleCustomerInfoUpdate(result.customerInfo);
  }

  /// Applies the server entitlement after app login or an offline cache
  /// restore.  This is deliberately separate from demo controls so actual
  /// expiry/trial timestamps are never replaced by invented values.
  void applyServerEntitlement({
    required String premiumType,
    int? expireTime,
    int? trialEndTime,
  }) {
    final type = switch (premiumType) {
      'annual' => PremiumType.annual,
      'monthly' => PremiumType.monthly,
      _ => PremiumType.free,
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    _applyPremiumState(
      expireTime != null && expireTime <= now ? PremiumType.free : type,
      expireTime: expireTime,
      trialEndTime: trialEndTime,
      isTrial: trialEndTime != null && trialEndTime > now,
    );
    notifyListeners();
  }

  Future<Package> _packageFor(Package? Function(Offering offering) select) async {
    _requirePurchasesConfiguration();
    final offering = (await Purchases.getOfferings()).current;
    final package = offering == null ? null : select(offering);
    if (package == null) {
      throw StateError('The selected subscription package is not available. Please try again later.');
    }
    return package;
  }

  void _requirePurchasesConfiguration() {
    if (!_purchasesConfigured) {
      throw StateError('Purchases are not configured in this build.');
    }
  }

  int? _parseExpiry(String? value) => DateTime.tryParse(value ?? '')?.millisecondsSinceEpoch;

  void _applyPremiumState(
    PremiumType type, {
    int? expireTime,
    int? trialEndTime,
    bool isTrial = false,
  }) {
    _premiumType = type;
    _isPremium = type != PremiumType.free;
    _isAnnual = type == PremiumType.annual;
    _expireTime = _isPremium ? expireTime : null;
    _trialEndTime = _isPremium ? trialEndTime : null;
    _isTrial = _isPremium && isTrial;
  }

  // 模拟Demo用：手动设置权限等级（沙盒测试）
  void setPremiumTypeForDemo(PremiumType type) {
    // Demo：设置模拟到期时间（monthly 30 天 / annual 365 天），供到期提醒逻辑使用
    final now = DateTime.now().millisecondsSinceEpoch;
    final expireTime = type == PremiumType.free
        ? null
        : now + (type == PremiumType.annual ? 365 : 30) * 24 * 60 * 60 * 1000;
    // §6.6：首次购买 Monthly/Annual 时开启 7 天免费试用
    if (type == PremiumType.monthly || type == PremiumType.annual) {
      _applyPremiumState(
        type,
        expireTime: expireTime,
        trialEndTime: now + 7 * 24 * 60 * 60 * 1000,
        isTrial: true,
      );
    } else {
      _applyPremiumState(PremiumType.free);
    }
    notifyListeners();
  }

  /// 检查订阅是否临近到期（3 天内），是则发一条本地提醒。
  Future<void> checkExpiryReminder() async {
    final exp = _expireTime;
    if (!_isPremium || exp == null) return;
    const threeDays = 3 * 24 * 60 * 60 * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (exp - now <= threeDays && exp > now) {
      await NotificationService.show(
        id: 1001,
        title: 'Subscription expiring soon',
        body: 'Your Freelance Hub subscription expires soon. Renew to keep Premium features.',
      );
    }
  }
}
