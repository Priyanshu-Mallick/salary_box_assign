import 'dart:async';

import 'package:attendance_mobile/src/domain/models/api_failure.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/auth_state.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(
  AuthViewModel.new,
);

class AuthViewModel extends Notifier<AuthState> {
  @override
  AuthState build() {
    unawaited(_restore());
    return const AuthState();
  }

  Future<void> _restore() async {
    try {
      final user = await ref.read(authRepositoryProvider).restore();
      state = AuthState(user: user, loading: false);
    } catch (_) {
      state = const AuthState(loading: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(email, password);
      state = AuthState(user: user, loading: false);
    } on ApiFailure catch (error) {
      state = state.copyWith(loading: false, error: error.message);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Sign in failed. Please try again.',
      );
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState(loading: false);
  }
}
