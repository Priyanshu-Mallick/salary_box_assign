import 'package:attendance_mobile/src/domain/repositories/attendance_repository.dart';
import 'package:attendance_mobile/src/domain/repositories/auth_repository.dart';
import 'package:attendance_mobile/src/domain/repositories/staff_repository.dart';
import 'package:attendance_mobile/src/domain/services/api_service.dart';
import 'package:attendance_mobile/src/domain/services/device_capture_service.dart';
import 'package:attendance_mobile/src/domain/services/session_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(sessions: ref.watch(sessionServiceProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return RestAuthRepository(ref.watch(apiServiceProvider));
});

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return RestStaffRepository(ref.watch(apiServiceProvider));
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return RestAttendanceRepository(ref.watch(apiServiceProvider));
});

final deviceCaptureServiceProvider = Provider<DeviceCaptureService>((ref) {
  return DeviceCaptureService();
});
