import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:week4_api/data/network_errors.dart';

void main() {
  test('maps connection timeout to a friendly message', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/posts'),
      type: DioExceptionType.connectionTimeout,
    );
    expect(friendlyErrorMessage(error), contains('Koneksi lambat'));
  });

  test('maps a 404 response to not found', () {
    final request = RequestOptions(path: '/posts/999');
    final error = DioException.badResponse(
      statusCode: 404,
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 404,
      ),
    );
    expect(friendlyErrorMessage(error), 'Data tidak ditemukan (404).');
  });

  test('falls back for unknown errors', () {
    expect(friendlyErrorMessage(StateError('boom')), contains('boom'));
  });
}