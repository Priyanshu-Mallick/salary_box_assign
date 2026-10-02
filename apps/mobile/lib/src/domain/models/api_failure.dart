import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_failure.freezed.dart';

@freezed
abstract class ApiFailure with _$ApiFailure implements Exception {
  const ApiFailure._();

  const factory ApiFailure(
    String code,
    String message, {
    @Default(false) bool retryable,
  }) = _ApiFailure;

  @override
  String toString() => message;
}
