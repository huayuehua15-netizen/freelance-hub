import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_info.dart';
import '../services/background_task_service.dart';
import '../services/hive_service.dart';
import '../services/api_service.dart';
import '../utils/currency_format.dart';

class AuthProvider extends ChangeNotifier {
  UserInfo? _user;
  String? _accessToken;
  String? _refreshToken;

  // 邮箱验证状态（内存态，随 /auth/me 刷新）：不写入 Hive——持久化一个
  // 可能过期的验证状态只会造成误判，横幅消失与否以服务端为准。
  bool _emailVerified = true;
  bool _emailVerificationAvailable = false;

  UserInfo? get user => _user;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isLoggedIn => _accessToken != null && _user != null;
  bool get emailVerified => _emailVerified;
  bool get emailVerificationAvailable => _emailVerificationAvailable;
  bool get showEmailVerificationBanner =>
      isLoggedIn && !_emailVerified && _emailVerificationAvailable;

  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUser = 'auth_user';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<void> login(String email, String password) async {
    final res = await ApiService().post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await _applySession(res['data'] as Map<String, dynamic>);
  }

  Future<void> register(String email, String password, String userName) async {
    final res = await ApiService().post('/auth/register', data: {
      'email': email,
      'password': password,
      'userName': userName,
    });
    await _applySession(res['data'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await ApiService().post('/auth/logout');
    } catch (_) {
      // 登出接口失败不阻断本地清理
    }
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    await _clearStorage();
    // 取消所有后台任务：登出后不再有登录用户，后台同步和计时提醒都应停止。
    // 注意：cancelAll 不影响未结束的计时（计时状态由 TimelogProvider 单独管理，
    // 这里只清理 workmanager 调度，避免向已登出设备发同步请求）。
    try {
      await BackgroundTaskService.cancelAll();
    } catch (e) {
      debugPrint('cancelAll on logout failed: $e');
    }
    notifyListeners();
  }

  /// GDPR 账户删除（§7.2）：先调后端软删除（30 天宽限期，需密码确认身份），
  /// 再清空本机用户数据。
  Future<void> deleteAccount({required String password}) async {
    await ApiService().delete('/auth/account', data: {'currentPassword': password});
    await _clearLocalData();
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    await _clearStorage();
    // 账号删除后所有后台任务都应停止。
    try {
      await BackgroundTaskService.cancelAll();
    } catch (e) {
      debugPrint('cancelAll on deleteAccount failed: $e');
    }
    notifyListeners();
  }

  Future<void> _clearLocalData() async {
    try {
      await HiveService.projectBoxInstance.clear();
      await HiveService.timeLogBoxInstance.clear();
      await HiveService.expenseBoxInstance.clear();
      await HiveService.userBoxInstance.clear();
      // 清空数据归属与设备 ID：本机数据已清空，下一个账号重新认领
      await HiveService.configBoxInstance.delete('data_owner_id');
      await HiveService.configBoxInstance.delete('device_id');
    } catch (_) {
      // 清理失败不阻断退出登录流程
    }
  }

  /// 供 ApiService 在 401 刷新成功后更新 token。
  Future<void> setTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _persistTokens();
    notifyListeners();
  }

  /// 忘记密码：发送重置邮件到任意邮箱（后端统一 200 防枚举）。
  Future<void> forgotPassword(String email) async {
    await ApiService().post('/auth/forgot-password', data: {'email': email});
  }

  /// 重发邮箱验证邮件（后端 60s 防轰炸，429 时抛错由 UI 提示）。
  Future<void> resendEmailVerification() async {
    await ApiService().post('/auth/resend-verification');
  }

  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var access = await _secureStorage.read(key: _kAccess);
      var refresh = await _secureStorage.read(key: _kRefresh);
      final userJson = prefs.getString(_kUser);

      // One-time migration from older builds that stored bearer tokens in
      // SharedPreferences (plaintext on many Android devices).
      if (access == null) {
        access = prefs.getString(_kAccess);
        refresh ??= prefs.getString(_kRefresh);
        if (access != null) {
          await _secureStorage.write(key: _kAccess, value: access);
          if (refresh != null) await _secureStorage.write(key: _kRefresh, value: refresh);
          await prefs.remove(_kAccess);
          await prefs.remove(_kRefresh);
        }
      }

      if (access != null && userJson != null) {
        // 恢复登录态
        _accessToken = access;
        _refreshToken = refresh;
        _user = UserInfo.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        CurrencyFormat.current = _user!.currency;
      } else {
        // 未登录：恢复本地 guest 偏好（货币/时区）
        final box = HiveService.userBoxInstance;
        final local = box.get('local_user');
        if (local != null) {
          _user = local;
          CurrencyFormat.current = local.currency;
        }
      }
    } catch (_) {
      // 读取失败降级为默认 USD，不阻断启动
    }
    notifyListeners();
  }

  /// Refreshes account/profile data when online.  Failure is intentionally
  /// non-fatal: an offline user keeps their locally cached account and data.
  Future<void> refreshCurrentUser() async {
    if (_accessToken == null || _user == null) return;
    try {
      final response = await ApiService().get('/auth/me');
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final previous = _user!;
      _user = UserInfo(
        userId: (data['userId'] as String?) ?? previous.userId,
        userName: (data['userName'] as String?) ?? previous.userName,
        userEmail: (data['userEmail'] as String?) ?? previous.userEmail,
        currency: (data['currency'] as String?) ?? previous.currency,
        timezone: (data['timezone'] as String?) ?? previous.timezone,
        isPremium: (data['premiumType'] as String? ?? previous.premiumType) != 'free',
        premiumType: (data['premiumType'] as String?) ?? previous.premiumType,
        expireTime: (data['expireTime'] as num?)?.toInt(),
        trialEndTime: (data['trialEndTime'] as num?)?.toInt(),
        lastSyncTime: (data['lastSyncTime'] as num?)?.toInt() ?? previous.lastSyncTime,
        createdAt: previous.createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _emailVerified = (data['emailVerified'] as bool?) ?? true;
      _emailVerificationAvailable = (data['emailVerificationAvailable'] as bool?) ?? false;
      CurrencyFormat.current = _user!.currency;
      await _persistSession();
      notifyListeners();
    } catch (_) {
      // Offline/temporarily unavailable: continue with the local session.
    }
  }

  /// 更新偏好（货币/时区）并持久化。
  Future<void> updatePreferences({String? currency, String? timezone}) async {
    final box = HiveService.userBoxInstance;
    final now = DateTime.now().millisecondsSinceEpoch;
    UserInfo user;
    if (_user == null) {
      user = UserInfo(
        userId: 'local_user',
        currency: currency ?? 'USD',
        timezone: timezone ?? 'America/New_York',
        createdAt: now,
        updatedAt: now,
      );
      _user = user;
    } else {
      user = _user!;
      if (currency != null) user.currency = currency;
      if (timezone != null) user.timezone = timezone;
      user.updatedAt = now;
    }
    await box.put(user.userId, user);
    CurrencyFormat.current = user.currency;
    if (_accessToken != null) await _persistSession();
    notifyListeners();
  }

  Future<void> _applySession(Map<String, dynamic> data) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final premiumType = (data['premiumType'] as String?) ?? 'free';
    _accessToken = data['accessToken'] as String;
    _refreshToken = data['refreshToken'] as String?;
    _user = UserInfo(
      userId: data['userId'] as String,
      userName: (data['userName'] as String?) ?? '',
      userEmail: (data['email'] as String?) ?? '',
      currency: (data['currency'] as String?) ?? 'USD',
      timezone: (data['timezone'] as String?) ?? 'America/New_York',
      isPremium: premiumType != 'free',
      premiumType: premiumType,
      expireTime: (data['expireTime'] as num?)?.toInt(),
      trialEndTime: (data['trialEndTime'] as num?)?.toInt(),
      createdAt: now,
      updatedAt: now,
    );
    CurrencyFormat.current = _user!.currency;
    await _persistSession();
    // 注册后台同步任务：登录成功后立刻注册，确保未同步数据在系统调度窗口内
    // 自动同步到云端。用 keep 策略，重复注册不会抛错。
    try {
      await BackgroundTaskService.registerBackgroundSync();
    } catch (e) {
      debugPrint('registerBackgroundSync on login failed: $e');
    }
    notifyListeners();
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken == null) {
      await _secureStorage.delete(key: _kAccess);
    } else {
      await _secureStorage.write(key: _kAccess, value: _accessToken);
    }
    if (_refreshToken == null) {
      await _secureStorage.delete(key: _kRefresh);
    } else {
      await _secureStorage.write(key: _kRefresh, value: _refreshToken);
    }
    await prefs.setString(_kUser, jsonEncode(_user?.toJson() ?? {}));
  }

  Future<void> _persistTokens() async {
    if (_accessToken == null) {
      await _secureStorage.delete(key: _kAccess);
    } else {
      await _secureStorage.write(key: _kAccess, value: _accessToken);
    }
    if (_refreshToken == null) {
      await _secureStorage.delete(key: _kRefresh);
    } else {
      await _secureStorage.write(key: _kRefresh, value: _refreshToken);
    }
  }

  Future<void> _clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _kAccess);
    await _secureStorage.delete(key: _kRefresh);
    // Clean up any old plaintext tokens as well.
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUser);
  }
}
