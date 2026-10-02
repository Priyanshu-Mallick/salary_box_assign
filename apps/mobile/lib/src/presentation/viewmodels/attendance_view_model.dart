import 'dart:async';

import 'package:attendance_mobile/src/domain/models/api_failure.dart';
import 'package:attendance_mobile/src/domain/models/attendance_submission.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/attendance_state.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef CaptureAttendancePhoto = Future<String?> Function();

final attendanceViewModelProvider =
    NotifierProvider<AttendanceViewModel, AttendanceState>(
      AttendanceViewModel.new,
    );

class AttendanceViewModel extends Notifier<AttendanceState> {
  @override
  AttendanceState build() {
    unawaited(Future.microtask(loadHistory));
    return const AttendanceState(loadingHistory: true);
  }

  Future<void> loadHistory() async {
    state = state.copyWith(loadingHistory: true);
    try {
      final history = await ref.read(attendanceRepositoryProvider).history();
      state = state.copyWith(history: history, loadingHistory: false);
    } catch (_) {
      state = state.copyWith(loadingHistory: false);
    }
  }

  void reset() => state = state.copyWith(
    step: AttendanceStep.ready,
    receipt: null,
    message: null,
  );

  Future<void> openSettings() =>
      ref.read(deviceCaptureServiceProvider).openSettings();

  Future<void> checkIn(CaptureAttendancePhoto capture) async {
    String? selfiePath;
    state = state.copyWith(
      step: AttendanceStep.location,
      receipt: null,
      message: null,
    );
    try {
      final devices = ref.read(deviceCaptureServiceProvider);
      var location = await devices.prepare();
      state = state.copyWith(step: AttendanceStep.camera);
      selfiePath = await capture();
      if (selfiePath == null) {
        reset();
        return;
      }
      final selfieAt = DateTime.now().toUtc();
      if (selfieAt.difference(location.capturedAt.toUtc()).abs() >
          const Duration(seconds: 20)) {
        location = await devices.currentLocation();
      }
      state = state.copyWith(step: AttendanceStep.submitting);
      final repository = ref.read(attendanceRepositoryProvider);
      final sessionId = await repository.createSession();
      final receipt = await repository.mark(
        AttendanceSubmission(
          captureSessionId: sessionId,
          selfiePath: selfiePath,
          latitude: location.latitude,
          longitude: location.longitude,
          accuracy: location.accuracy,
          isMocked: location.isMocked,
          selfieCapturedAt: selfieAt,
          locationCapturedAt: location.capturedAt,
        ),
      );
      state = state.copyWith(step: AttendanceStep.success, receipt: receipt);
      await loadHistory();
    } on ApiFailure catch (error) {
      state = state.copyWith(
        step: error.code == 'PERMISSION_REQUIRED'
            ? AttendanceStep.permission
            : AttendanceStep.failure,
        message: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        step: AttendanceStep.failure,
        message: 'The check-in could not be completed. Please try again.',
      );
    } finally {
      if (selfiePath != null) {
        await ref.read(deviceCaptureServiceProvider).deleteFiles([selfiePath]);
      }
    }
  }
}
