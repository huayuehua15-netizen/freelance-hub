import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';

/// 统一 API 异常
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  AuthProvider? _authProvider;

  // 401 刷新 single-flight（P1）：并发多个 401 只发起一次 /auth/refresh，
  // 其余请求挂同一 future 等待刷新完成后再重试。后端 refresh token 原子
  // 轮换（M5）下，并发刷新会让后到者因旧 token 已失效而 401 → 误伤本可
  // 恢复的请求。刷新失败时 future 清空，允许后续请求重新尝试。
  Future<void>? _refreshing;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 自动加 Authorization: Bearer {token}
        final token = _authProvider?.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // 同步当前语言偏好到后端,使后端返回本地化错误消息
        options.headers['Accept-Language'] =
            AppLocalizations.isZh ? 'zh-CN' : 'en';
        return handler.next(options);
      },
      onError: (error, handler) async {
        final code = error.response?.statusCode;
        final options = error.requestOptions;

        // 401：用 refreshToken 刷新后重试一次。排除两类端点：
        //   - /auth/refresh：刷新自身失败，再 refresh 会递归死循环
        //   - /auth/login：登录失败（用户不存在/密码错误）是业务错误，不该用旧
        //     refreshToken 尝试刷新；否则会把"Invalid email or password"误变成
        //     "Session expired"，且会对已注销账号的旧 token 做无意义轮换。
        if (code == 401 &&
            options.path != '/auth/refresh' &&
            options.path != '/auth/login' &&
            options.extra['_retried'] != true) {
          final refresh = _authProvider?.refreshToken;
          if (refresh != null && refresh.isNotEmpty) {
            try {
              await _refreshAccessToken();
              // 刷新成功后用最新 access token 重试原请求（并发场景下
              // 其它 401 请求可能已先完成轮换，这里重新读取当前 token）
              options.extra['_retried'] = true;
              final currentToken = _authProvider?.accessToken;
              if (currentToken != null) {
                options.headers['Authorization'] = 'Bearer $currentToken';
              }
              final retryRes = await _dio.fetch(options);
              return handler.resolve(retryRes);
            } catch (_) {
              // 刷新失败，走默认 401 处理（提示重新登录）
            }
          }
        }
        return handler.next(error);
      },
    ));
  }

  /// 并发互斥刷新：同批 401 共享同一 refresh 请求。
  Future<void> _refreshAccessToken() {
    final inflight = _refreshing;
    if (inflight != null) return inflight;
    final refresh = _authProvider?.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      return Future.error(StateError('No refresh token available'));
    }
    final future = _doRefresh(refresh).whenComplete(() => _refreshing = null);
    _refreshing = future;
    return future;
  }

  Future<void> _doRefresh(String refresh) async {
    final refreshRes = await _dio.post(
      '/auth/refresh',
      data: {'refreshToken': refresh},
    );
    final map = Map<String, dynamic>.from(refreshRes.data as Map);
    final data = map['data'] as Map<String, dynamic>;
    final access = data['accessToken'] as String;
    final newRefresh = (data['refreshToken'] as String?) ?? refresh;
    await _authProvider?.setTokens(access, newRefresh);
  }

  void setAuthProvider(AuthProvider provider) {
    _authProvider = provider;
  }

  Dio get dio => _dio;

  // 通用请求方法（统一返回 {code, msg, data}，业务错误抛 ApiException）
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    return _request(() => _dio.get(path, queryParameters: query));
  }

  Future<Map<String, dynamic>> post(String path, {dynamic data}) async {
    return _request(() => _dio.post(path, data: data));
  }

  Future<Map<String, dynamic>> put(String path, {dynamic data}) async {
    return _request(() => _dio.put(path, data: data));
  }

  Future<Map<String, dynamic>> delete(String path, {dynamic data}) async {
    return _request(() => _dio.delete(path, data: data));
  }

  Future<Map<String, dynamic>> _request(Future<Response> Function() call) async {
    try {
      final res = await call();
      return _parse(res);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// 统一返回格式处理：{code, msg, data}。code 非 0/200 视为业务错误
  Map<String, dynamic> _parse(Response res) {
    final data = res.data;
    if (data is! Map) {
      return data == null ? <String, dynamic>{} : <String, dynamic>{'data': data};
    }
    final map = Map<String, dynamic>.from(data);
    final code = map['code'];
    if (code != null && code != 0 && code != 200) {
      throw ApiException(
        code is int ? code : int.tryParse('$code'),
        (map['msg'] as String?) ?? 'Request failed',
      );
    }
    return map;
  }

  ApiException _toApiException(DioException e) {
    final code = e.response?.statusCode;
    // 优先采用后端返回的 msg 字段（如 "Invalid email or password"），更准确；
    // 后端没给 msg 时才回退到本地默认文案，使用当前语言本地化。
    final body = e.response?.data;
    String? serverMsg;
    if (body is Map) {
      final m = body['msg'];
      if (m is String && m.trim().isNotEmpty) serverMsg = m;
    }
    String msg;
    switch (code) {
      case 401:
        msg = serverMsg ?? AppLocalizations.t('errors.sessionExpired');
        break;
      case 403:
        msg = serverMsg ?? AppLocalizations.t('errors.permissionDenied');
        break;
      case 404:
        msg = serverMsg ?? AppLocalizations.t('errors.notFound');
        break;
      case 500:
      case 502:
      case 503:
        msg = serverMsg ?? AppLocalizations.t('errors.serverError');
        break;
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          msg = AppLocalizations.t('errors.timeout');
        } else {
          msg = serverMsg ?? e.message ?? AppLocalizations.t('errors.networkError');
        }
    }
    return ApiException(code, msg);
  }
}
