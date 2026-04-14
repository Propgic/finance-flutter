import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;
  ApiException(this.message, {this.statusCode, this.data});
  @override
  String toString() => message;
}

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
      if (code == 401) {
        // token invalid; clear and bubble up
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('user');
        await prefs.remove('org');
        await prefs.remove('permissions');
      }
      throw ApiException(msg, statusCode: code, data: data);
    }
  }
}

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5008/api';
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
    validateStatus: (s) => s != null && s < 500,
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (opts, handler) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null && token.isNotEmpty) {
        opts.headers['Authorization'] = 'Bearer $token';
      }
      if (opts.data is FormData) {
        opts.headers.remove('Content-Type');
      }
      handler.next(opts);
    },
    onResponse: (res, handler) {
      if (res.statusCode != null && res.statusCode! >= 400) {
        handler.reject(DioException(
          requestOptions: res.requestOptions,
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
