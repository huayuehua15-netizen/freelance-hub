import 'package:dio/dio.dart';
import '../config/app_config.dart';
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
        return handler.next(options);
      },
      onError: (error, handler) async {
        final code = error.response?.statusCode;
        final options = error.requestOptions;

        // 401：用 refreshToken 刷新后重试一次（刷新接口自身不再重试，避免死循环）
        if (code == 401 &&
            options.path != '/auth/refresh' &&
            options.extra['_retried'] != true) {
          final refresh = _authProvider?.refreshToken;
          if (refresh != null && refresh.isNotEmpty) {
            try {
              final refreshRes = await _dio.post(
                '/auth/refresh',
                data: {'refreshToken': refresh},
              );
              final map = Map<String, dynamic>.from(refreshRes.data as Map);
              final data = map['data'] as Map<String, dynamic>;
              final access = data['accessToken'] as String;
              final newRefresh = (data['refreshToken'] as String?) ?? refresh;
              await _authProvider?.setTokens(access, newRefresh);

              options.extra['_retried'] = true;
              options.headers['Authorization'] = 'Bearer $access';
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

  Future<Map<String, dynamic>> delete(String path) async {
    return _request(() => _dio.delete(path));
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
    String msg;
    switch (code) {
      case 401:
        msg = 'Session expired, please sign in again';
        break;
      case 403:
        msg = 'Permission denied';
        break;
      case 404:
        msg = 'Resource not found';
        break;
      case 500:
      case 502:
      case 503:
        msg = 'Server error, please try again later';
        break;
      default:
        if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          msg = 'Request timed out';
        } else {
          msg = e.message ?? 'Network error';
        }
    }
    return ApiException(code, msg);
  }
}
