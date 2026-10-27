import 'package:dio/dio.dart';

enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  validation,
  conflict,
  rateLimited,
  notFound,
  server,
  unknown,
}

/// Error from the API. [message] is the backend `detail` when there is one;
/// otherwise null and the UI shows a localized fallback for [kind].
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    this.status,
    this.message,
    this.code,
    this.retryAfterSeconds,
  });

  final ApiErrorKind kind;
  final int? status;
  final String? message;

  /// Value of the `X-Error-Code` header, e.g. `no_nurse_free`.
  final String? code;
  final int? retryAfterSeconds;

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      final timeout =
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
      return ApiException(
        kind: timeout ? ApiErrorKind.timeout : ApiErrorKind.network,
      );
    }
    final status = res.statusCode ?? 0;
    final data = res.data;
    String? message;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) {
        message = d;
      } else if (d is List && d.isNotEmpty && d.first is Map) {
        message = (d.first as Map)['msg']?.toString();
      }
    }
    final code =
        res.headers.value('x-error-code') ??
        (data is Map ? data['code']?.toString() : null);
    final retry = int.tryParse(res.headers.value('retry-after') ?? '');
    final kind = switch (status) {
      401 => ApiErrorKind.unauthorized,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      429 => ApiErrorKind.rateLimited,
      400 || 422 => ApiErrorKind.validation,
      >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.unknown,
    };
    return ApiException(
      kind: kind,
      status: status,
      message: message,
      code: code,
      retryAfterSeconds: retry,
    );
  }

  @override
  String toString() => 'ApiException($kind, $status, $code, $message)';
}
