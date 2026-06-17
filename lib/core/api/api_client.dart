import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../maintenance/maintenance_controller.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;
  ApiException(this.message, {this.statusCode, this.data});
  @override
  String toString() => message;
}

// Tokens at rest: the short-lived access token and the long-lived refresh token
// live in the OS keychain/keystore (flutter_secure_storage), NOT SharedPreferences.
// A token left in SharedPreferences by an older build is read once as a legacy
// fallback and migrated into secure storage on the next refresh.
const _secure = FlutterSecureStorage();

class TokenStore {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  static Future<String?> access() async {
    final t = await _secure.read(key: _kAccess);
    if (t != null && t.isNotEmpty) return t;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token'); // legacy fallback
  }

  static Future<String?> refresh() => _secure.read(key: _kRefresh);

  static Future<void> save({String? access, String? refresh}) async {
    if (access != null) await _secure.write(key: _kAccess, value: access);
    if (refresh != null) await _secure.write(key: _kRefresh, value: refresh);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token'); // migrate off legacy storage
  }

  static Future<void> clear() async {
    await _secure.delete(key: _kAccess);
    await _secure.delete(key: _kRefresh);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
}

// Bare Dio (no interceptors) used for the refresh call and the retried request,
// so neither recurses back through the refresh interceptor.
final Dio _bareDio = Dio();

// Single-flight: concurrent 401s share one /auth/refresh round-trip.
Future<String?>? _refreshing;
Future<String?> _refreshAccessToken(String baseUrl) {
  _refreshing ??= _performRefresh(baseUrl).whenComplete(() => _refreshing = null);
  return _refreshing!;
}

Future<String?> _performRefresh(String baseUrl) async {
  final rt = await TokenStore.refresh();
  if (rt == null || rt.isEmpty) return null;
  try {
    final res = await _bareDio.post(
      '$baseUrl/auth/refresh',
      data: {'refreshToken': rt},
      options: Options(headers: {'Content-Type': 'application/json', 'X-Client-Platform': 'mobile'}),
    );
    final body = res.data;
    final data = (body is Map && body['data'] != null) ? body['data'] : body;
    final access = (data is Map ? data['token'] : null) as String?;
    final newRefresh = (data is Map ? data['refreshToken'] : null) as String?;
    if (access != null && access.isNotEmpty) {
      await TokenStore.save(access: access, refresh: newRefresh);
      return access;
    }
    return null;
  } catch (_) {
    return null;
  }
}

bool _shouldRefresh(RequestOptions o) =>
    o.extra['retried'] != true &&
    !o.path.contains('/auth/refresh') &&
    !o.path.contains('/auth/login');

class ApiClient {
  final Dio dio;
  final Ref ref;

  ApiClient(this.dio, this.ref);

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return _wrap(() => dio.get(path, queryParameters: query));
  }

  Future<dynamic> post(String path, {dynamic data, Map<String, dynamic>? query}) async {
    return _wrap(() => dio.post(path, data: data, queryParameters: query));
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    return _wrap(() => dio.put(path, data: data));
  }

  Future<dynamic> patch(String path, {dynamic data}) async {
    return _wrap(() => dio.patch(path, data: data));
  }

  Future<dynamic> delete(String path, {dynamic data}) async {
    return _wrap(() => dio.delete(path, data: data));
  }

  Future<Response> raw(Future<Response> Function() fn) => _wrapRaw(fn);

  Future<dynamic> _wrap(Future<Response> Function() fn) async {
    final res = await _wrapRaw(fn);
    final body = res.data;
    if (body is Map && body['success'] == false) {
      throw ApiException(body['message']?.toString() ?? 'Request failed',
          statusCode: res.statusCode, data: body);
    }
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  Future<Response> _wrapRaw(Future<Response> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      String msg = 'Network error';
      if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      } else if (e.message != null) {
        msg = e.message!;
      }
      if (code == 503) {
        // Platform-wide or per-org maintenance — show the full-screen blocker.
        ref.read(maintenanceProvider.notifier).trigger(msg);
      }
      if (code == 401) {
        // Refresh already attempted+failed in the interceptor; tear down.
        await TokenStore.clear();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user');
        await prefs.remove('org');
        await prefs.remove('permissions');
      }
      throw ApiException(msg, statusCode: code, data: data);
    }
  }
}

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = 'https://api.rupit.in/api';//dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5008/api';
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    // Identify this client so the backend enforces per-member platform access
    // and returns the refresh token in the body (mobile) rather than a cookie.
    headers: {'Content-Type': 'application/json', 'X-Client-Platform': 'mobile'},
    validateStatus: (s) => s != null && s < 500,
  ));

  // API request/response logger (debug builds only)
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestHeader: true,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
      logPrint: (obj) => debugPrint('[API] $obj'),
    ));
  }

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (opts, handler) async {
      final token = await TokenStore.access();
      if (token != null && token.isNotEmpty) {
        opts.headers['Authorization'] = 'Bearer $token';
      }
      if (opts.data is FormData) {
        opts.headers.remove('Content-Type');
      }
      handler.next(opts);
    },
    onResponse: (res, handler) async {
      final o = res.requestOptions;
      final code = res.statusCode;

      // Access token expired → silently refresh (single-flight) and retry once.
      // This is where a deactivation takes effect: refresh re-checks isActive and
      // returns 401, so the retry stays 401 and we clear the session.
      if (code == 401 && _shouldRefresh(o)) {
        final newToken = await _refreshAccessToken(o.baseUrl);
        if (newToken == null) {
          await TokenStore.clear();
        } else if (o.data is! FormData) {
          try {
            o.headers['Authorization'] = 'Bearer $newToken';
            o.extra['retried'] = true;
            final retried = await _bareDio.fetch(o);
            if (retried.statusCode == 401) await TokenStore.clear();
            return handler.resolve(retried);
          } catch (_) {
            // network error on retry — fall through to reject the original 401
          }
        }
      }

      if (code != null && code >= 400) {
        handler.reject(DioException(
          requestOptions: o,
          response: res,
          type: DioExceptionType.badResponse,
        ));
        return;
      }
      handler.next(res);
    },
  ));
  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider), ref);
});
