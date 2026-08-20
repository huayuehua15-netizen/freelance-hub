import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_service.dart';

enum PremiumType { free, monthly, annual }

/// 用户主动取消购买（关闭 Google Play 结算弹窗）时抛出。
/// UI 层应友好提示而非当作错误展示。
class PurchaseCanceledException implements Exception {
  final String message;
  PurchaseCanceledException([this.message = 'Purchase was canceled by the user.']);
  @override
  String toString() => message;
}

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

    try {
      final configuration = PurchasesConfiguration(AppConfig.revenueCatApiKey)
        ..appUserID = appUserId;
      await Purchases.configure(configuration);
      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);
      _purchasesConfigured = true;
      await _refreshCustomerInfo();
    } catch (_) {
      // 配置/网络失败时允许下次重试（如回到前台再 initialize），
      // 否则本会话内购买/恢复永远报 "not configured"。
      _isInitialized = false;
      rethrow;
    }
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
    try {
      final info = await Purchases.purchasePackage(package);
      _handleCustomerInfoUpdate(info);
    } on PlatformException catch (e) {
      throw _wrapPurchaseError(e);
    }
  }

  Future<void> purchaseAnnual() async {
    final package = await _packageFor((offering) => offering.annual);
    try {
      final info = await Purchases.purchasePackage(package);
      _handleCustomerInfoUpdate(info);
    } on PlatformException catch (e) {
      throw _wrapPurchaseError(e);
    }
  }

  /// 将 RevenueCat 抛出的 [PlatformException] 转换为业务语义异常：
  /// - 用户主动取消 → [PurchaseCanceledException]（UI 应静默/友好提示）
  /// - 其他错误原样向上抛，由调用处按失败处理。
  ///
  /// 注意：purchases_flutter 的 PlatformException.code 是**数字字符串**
  /// （PurchasesErrorHelper.getErrorCode 内部是 int.parse(e.code)），
  /// 不能与 'PURCHASE_CANCELLED' 之类的常量字符串比较。
  Exception _wrapPurchaseError(PlatformException e) {
    try {
      if (PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseCanceledException();
      }
    } catch (_) {
      // code 非数字（通道级错误）时 getErrorCode 抛 FormatException，按普通错误处理
    }
    return Exception(e.message ?? e.code);
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

  /// 获取商店真实产品信息（本地货币价格 + 是否有免费试用 IntroductoryOffer）。
  /// 订阅页必须展示商店价格：硬编码 $4.79 对 EUR/VAT 地区用户是错误标价，
  /// 属 Google Play「误导性声明」风险；试用期标注也必须以商店配置为准。
  /// 未配置 RC 或 offerings 拉取失败时返回 null（UI 回退到参考价并提示）。
  Future<({String? monthlyPrice, String? annualPrice, bool monthlyHasTrial, bool annualHasTrial})>
      fetchStoreProducts() async {
    if (!_purchasesConfigured) {
      return (monthlyPrice: null, annualPrice: null, monthlyHasTrial: false, annualHasTrial: false);
    }
    try {
      final offering = (await Purchases.getOfferings()).current;
      final monthly = offering?.monthly?.storeProduct;
      final annual = offering?.annual?.storeProduct;
      bool hasTrial(StoreProduct? p) =>
          p?.introductoryPrice != null && p!.introductoryPrice!.price == 0;
      return (
        monthlyPrice: monthly?.priceString,
        annualPrice: annual?.priceString,
        monthlyHasTrial: hasTrial(monthly),
        annualHasTrial: hasTrial(annual),
      );
    } catch (_) {
      return (monthlyPrice: null, annualPrice: null, monthlyHasTrial: false, annualHasTrial: false);
    }
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
      // 订阅到期提醒 ID 与计时器晚间提醒（1001）错开，避免互相覆盖
      await NotificationService.show(
        id: 1002,
        title: AppLocalizations.t('notification.subscriptionExpiringTitle'),
        body: AppLocalizations.t('notification.subscriptionExpiringBody'),
      );
    }
  }
}
