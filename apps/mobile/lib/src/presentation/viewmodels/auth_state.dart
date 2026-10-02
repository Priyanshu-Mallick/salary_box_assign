import 'package:attendance_mobile/src/domain/models/app_user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';

@freezed
abstract class AuthState with _$AuthState {
  const factory AuthState({
    AppUser? user,
    @Default(true) bool loading,
    String? error,
  }) = _AuthState;
}
