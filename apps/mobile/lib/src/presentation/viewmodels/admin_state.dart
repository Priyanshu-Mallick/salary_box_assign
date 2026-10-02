import 'package:attendance_mobile/src/domain/models/staff_member.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_state.freezed.dart';

@freezed
abstract class AdminState with _$AdminState {
  const AdminState._();

  const factory AdminState({
    @Default([]) List<StaffMember> staff,
    StaffMember? selected,
    @Default('') String query,
    @Default(false) bool loading,
    @Default(false) bool saving,
    String? error,
  }) = _AdminState;

  List<StaffMember> get visibleStaff {
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return staff;
    return staff
        .where(
          (item) =>
              item.name.toLowerCase().contains(value) ||
              item.employeeId.toLowerCase().contains(value),
        )
        .toList(growable: false);
  }

  int get enrolledCount =>
      staff.where((item) => item.enrolmentStatus == 'active').length;
}
