import 'package:attendance_mobile/src/domain/models/attendance_receipt.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'attendance_state.freezed.dart';

enum AttendanceStep {
  ready,
  permission,
  location,
  camera,
  submitting,
  success,
  failure,
}

@freezed
abstract class AttendanceState with _$AttendanceState {
  const factory AttendanceState({
    @Default([]) List<AttendanceReceipt> history,
    @Default(false) bool loadingHistory,
    @Default(AttendanceStep.ready) AttendanceStep step,
    AttendanceReceipt? receipt,
    String? message,
  }) = _AttendanceState;
}
