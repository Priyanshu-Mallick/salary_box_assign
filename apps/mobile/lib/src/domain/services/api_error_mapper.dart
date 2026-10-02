import 'package:attendance_mobile/src/domain/models/api_failure.dart';
import 'package:dio/dio.dart';

abstract final class ApiErrorMapper {
  static ApiFailure fromDio(DioException error) {
    final body = error.response?.data;
    if (body is Map<String, dynamic> && body['error'] is Map<String, dynamic>) {
      final detail = body['error'] as Map<String, dynamic>;
      return ApiFailure(
        detail['code'] as String? ?? 'API_ERROR',
        detail['message'] as String? ?? 'The request failed.',
        retryable: detail['retryable'] as bool? ?? false,
      );
    }
    return ApiFailure(
      'NETWORK_ERROR',
      error.type == DioExceptionType.connectionTimeout
          ? 'The server took too long to respond.'
          : 'Could not reach the attendance service.',
      retryable: true,
    );
  }
}
