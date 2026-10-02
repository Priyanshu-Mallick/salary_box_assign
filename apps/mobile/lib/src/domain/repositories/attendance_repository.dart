import 'dart:convert';

import 'package:attendance_mobile/src/domain/models/attendance_receipt.dart';
import 'package:attendance_mobile/src/domain/models/attendance_submission.dart';
import 'package:attendance_mobile/src/domain/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

abstract interface class AttendanceRepository {
  Future<String> createSession();
  Future<AttendanceReceipt> mark(AttendanceSubmission submission);
  Future<List<AttendanceReceipt>> history();
}

class RestAttendanceRepository implements AttendanceRepository {
  RestAttendanceRepository(this._api, {Uuid uuid = const Uuid()})
    : _uuid = uuid;
  final ApiService _api;
  final Uuid _uuid;

  @override
  Future<String> createSession() async {
    final data = await _api.request<Map<String, dynamic>>(
      'POST',
      '/attendance-sessions',
      data: {'consent_version': 'demo-privacy-v1', 'consent_accepted': true},
      headers: {'Idempotency-Key': _uuid.v4()},
    );
    return data['id'] as String;
  }

  @override
  Future<AttendanceReceipt> mark(AttendanceSubmission submission) async {
    final metadata = jsonEncode({
      'capture_session_id': submission.captureSessionId,
      'selfie_captured_at': submission.selfieCapturedAt
          .toUtc()
          .toIso8601String(),
      'location': {
        'latitude': submission.latitude,
        'longitude': submission.longitude,
        'accuracy_m': submission.accuracy,
        'captured_at': submission.locationCapturedAt.toUtc().toIso8601String(),
        'is_mocked': submission.isMocked,
      },
      'consent_version': 'demo-privacy-v1',
    });
    final data = await _api.request<Map<String, dynamic>>(
      'POST',
      '/attendance',
      data: FormData.fromMap({
        'metadata': metadata,
        'selfie': MultipartFile.fromFileSync(
          submission.selfiePath,
          filename: 'attendance.jpg',
          contentType: DioMediaType.parse('image/jpeg'),
        ),
      }),
      headers: {'Idempotency-Key': _uuid.v4()},
    );
    return AttendanceReceipt.fromJson(data);
  }

  @override
  Future<List<AttendanceReceipt>> history() async {
    final data = await _api.request<Map<String, dynamic>>('GET', '/attendance');
    return (data['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AttendanceReceipt.fromJson)
        .toList(growable: false);
  }
}
