import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'token_store.dart';

/// Thin wrapper over Dio: bearer token, error mapping, 401 callback.
/// Only repositories use this; screens never see Dio.
class ApiClient {
  ApiClient({required String baseUrl, required this.tokens, this.onUnauthorized, Dio? dio})
      : dio = dio ?? Dio() {
    this.dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30)
      ..headers = {'Accept': 'application/json'};
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokens.read();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (e, handler) async {
          final isAuthCall = e.requestOptions.path.startsWith('/auth/phone');
          if (e.response?.statusCode == 401 && !isAuthCall) {
            await tokens.clear();
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );
  }

  final Dio dio;
  final TokenStore tokens;
  final void Function()? onUnauthorized;

  Future<T> _run<T>(Future<Response<dynamic>> Function() call, T Function(dynamic data) parse) async {
    try {
      final res = await call();
      return parse(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<T> get<T>(String path, T Function(dynamic) parse, {Map<String, dynamic>? query}) =>
      _run(() => dio.get<dynamic>(path, queryParameters: query), parse);

  Future<T> post<T>(String path, T Function(dynamic) parse, {Object? body}) =>
      _run(() => dio.post<dynamic>(path, data: body), parse);

  Future<T> patch<T>(String path, T Function(dynamic) parse, {Object? body}) =>
      _run(() => dio.patch<dynamic>(path, data: body), parse);

  Future<void> delete(String path, {Object? body}) =>
      _run(() => dio.delete<dynamic>(path, data: body), (_) {});

  Future<void> postVoid(String path, {Object? body}) => _run(() => dio.post<dynamic>(path, data: body), (_) {});
}
