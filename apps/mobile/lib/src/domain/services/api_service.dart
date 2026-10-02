import 'package:attendance_mobile/src/domain/models/api_failure.dart';
import 'package:attendance_mobile/src/domain/services/api_error_mapper.dart';
import 'package:attendance_mobile/src/domain/services/session_service.dart';
import 'package:dio/dio.dart';

class ApiService {
  ApiService({Dio? dio, SessionService? sessions})
    : _dio = dio ?? Dio(BaseOptions(baseUrl: _defaultBaseUrl)),
      _sessions = sessions ?? SessionService();

  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
  final Dio _dio;
  final SessionService _sessions;
  SessionData? _session;
  Future<void>? _refreshing;

  Future<bool> restoreSession() async {
    _session = await _sessions.read();
    return _session != null;
  }

  Future<void> saveSession(Map<String, dynamic> data) async {
    final session = SessionData(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: data['expires_in'] as int? ?? 900),
      ),
    );
    _session = session;
    await _sessions.write(session);
  }

  Future<void> clearSession() async {
    _session = null;
    await _sessions.clear();
  }

  Future<T> request<T>(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? headers,
    bool authenticated = true,
  }) async {
    try {
      if (authenticated) await _ensureFreshToken();
      final response = await _dio.request<T>(
        path,
        data: data,
        options: Options(
          method: method,
          headers: {
            if (authenticated && _session != null)
              'Authorization': 'Bearer ${_session!.accessToken}',
            ...?headers,
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      return response.data as T;
    } on DioException catch (error) {
      throw ApiErrorMapper.fromDio(error);
    }
  }

  Future<void> _ensureFreshToken() async {
    final session = _session;
    if (session == null) {
      throw const ApiFailure(
        'SESSION_EXPIRED',
        'Your session expired. Please sign in again.',
      );
    }
    final safeUntil = DateTime.now().toUtc().add(const Duration(seconds: 30));
    if (session.expiresAt.isAfter(safeUntil)) return;
    final existing = _refreshing;
    if (existing != null) return existing;
    final refresh = _refreshSession(session.refreshToken);
    _refreshing = refresh;
    try {
      await refresh;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _refreshSession(String refreshToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      await saveSession(response.data!);
    } on DioException {
      await clearSession();
      throw const ApiFailure(
        'SESSION_EXPIRED',
        'Your session expired. Please sign in again.',
      );
    }
  }
}
