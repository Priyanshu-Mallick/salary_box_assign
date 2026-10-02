import 'package:freezed_annotation/freezed_annotation.dart';

part 'attendance_submission.freezed.dart';

@freezed
abstract class AttendanceSubmission with _$AttendanceSubmission {
  const factory AttendanceSubmission({
    required String captureSessionId,
    required String selfiePath,
    required double latitude,
    required double longitude,
    required double accuracy,
    required bool isMocked,
    required DateTime selfieCapturedAt,
    required DateTime locationCapturedAt,
  }) = _AttendanceSubmission;
}

@freezed
abstract class LocationSnapshot with _$LocationSnapshot {
  const factory LocationSnapshot({
    required double latitude,
    required double longitude,
    required double accuracy,
    required bool isMocked,
    required DateTime capturedAt,
  }) = _LocationSnapshot;
}
