import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_info.dart';
import '../services/hive_service.dart';
import '../services/api_service.dart';
import '../utils/currency_format.dart';

class AuthProvider extends ChangeNotifier {
  UserInfo? _user;
  String? _accessToken;
  String? _refreshToken;

  UserInfo? get user => _user;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isLoggedIn => _accessToken != null && _user != null;

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
    notifyListeners();
  }

  /// GDPR 账户删除（§7.2）：先调后端软删除（30 天宽限期），再清空本机用户数据。
  Future<void> deleteAccount() async {
    await ApiService().delete('/auth/account');
    await _clearLocalData();
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    await _clearStorage();
    notifyListeners();
  }

  Future<void> _clearLocalData() async {
    try {
      await HiveService.projectBoxInstance.clear();
      await HiveService.timeLogBoxInstance.clear();
      await HiveService.expenseBoxInstance.clear();
      await HiveService.userBoxInstance.clear();
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
        userEmail: (data['email'] as String?) ?? previous.userEmail,
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
