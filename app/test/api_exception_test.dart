import 'package:carenest/data/api/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _err(
  int status,
  Object? data, {
  Map<String, List<String>>? headers,
}) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: req,
      statusCode: status,
      data: data,
      headers: Headers.fromMap(headers ?? {}),
    ),
  );
}

void main() {
  test('reads string detail and X-Error-Code', () {
    final e = ApiException.fromDio(
      _err(
        409,
        {'detail': 'No nurse is free'},
        headers: {
          'x-error-code': ['no_nurse_free'],
        },
      ),
    );
    expect(e.kind, ApiErrorKind.conflict);
    expect(e.message, 'No nurse is free');
    expect(e.code, 'no_nurse_free');
  });

  test('reads the first message of a 422 detail list', () {
    final e = ApiException.fromDio(
      _err(422, {
        'detail': [
          {
            'loc': ['body', 'phone'],
            'msg': 'Field required',
            'type': 'missing',
          },
        ],
      }),
    );
    expect(e.kind, ApiErrorKind.validation);
    expect(e.message, 'Field required');
  });

  test('429 keeps Retry-After', () {
    final e = ApiException.fromDio(
      _err(
        429,
        {'detail': 'Wait'},
        headers: {
          'retry-after': ['42'],
        },
      ),
    );
    expect(e.kind, ApiErrorKind.rateLimited);
    expect(e.retryAfterSeconds, 42);
  });

  test('401 is unauthorized and no response is a network error', () {
    expect(
      ApiException.fromDio(_err(401, {'detail': 'x'})).kind,
      ApiErrorKind.unauthorized,
    );
    final net = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
    );
    expect(ApiException.fromDio(net).kind, ApiErrorKind.network);
    final slow = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.receiveTimeout,
    );
    expect(ApiException.fromDio(slow).kind, ApiErrorKind.timeout);
  });
}
