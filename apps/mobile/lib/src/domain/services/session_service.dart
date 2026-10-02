import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionData {
  const SessionData({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
}

class SessionService {
  SessionService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'attendance.access_token';
  static const _refreshKey = 'attendance.refresh_token';
  static const _expiryKey = 'attendance.access_expiry';
  final FlutterSecureStorage _storage;

  Future<SessionData?> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    final expiry = DateTime.tryParse(
      await _storage.read(key: _expiryKey) ?? '',
    );
    if (access == null || refresh == null || expiry == null) return null;
    return SessionData(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiry,
    );
  }

  Future<void> write(SessionData session) async {
    await Future.wait([
      _storage.write(key: _accessKey, value: session.accessToken),
      _storage.write(key: _refreshKey, value: session.refreshToken),
      _storage.write(
        key: _expiryKey,
        value: session.expiresAt.toIso8601String(),
      ),
    ]);
  }

  Future<void> clear() => Future.wait([
    _storage.delete(key: _accessKey),
    _storage.delete(key: _refreshKey),
    _storage.delete(key: _expiryKey),
  ]);
}
