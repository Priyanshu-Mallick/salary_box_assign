import 'package:attendance_mobile/src/domain/models/api_failure.dart';
import 'package:attendance_mobile/src/domain/models/app_user.dart';
import 'package:attendance_mobile/src/domain/services/api_service.dart';

abstract interface class AuthRepository {
  Future<AppUser?> restore();
  Future<AppUser> login(String email, String password);
  Future<void> logout();
}

class RestAuthRepository implements AuthRepository {
  RestAuthRepository(this._api);
  final ApiService _api;

  @override
  Future<AppUser?> restore() async {
    if (!await _api.restoreSession()) return null;
    try {
      return await _me();
    } on ApiFailure {
      await _api.clearSession();
      return null;
    }
  }

  @override
  Future<AppUser> login(String email, String password) async {
    final data = await _api.request<Map<String, dynamic>>(
      'POST',
      '/auth/login',
      data: {'email': email.trim(), 'password': password},
      authenticated: false,
    );
    await _api.saveSession(data);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  @override
  Future<void> logout() async {
    try {
      await _api.request<Object?>('POST', '/auth/logout');
    } finally {
      await _api.clearSession();
    }
  }

  Future<AppUser> _me() async =>
      AppUser.fromJson(await _api.request<Map<String, dynamic>>('GET', '/me'));
}
