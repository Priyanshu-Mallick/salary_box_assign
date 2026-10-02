import 'package:freezed_annotation/freezed_annotation.dart';

part 'staff_member.freezed.dart';
part 'staff_member.g.dart';

@freezed
abstract class StaffMember with _$StaffMember {
  const factory StaffMember({
    required String id,
    required String name,
    @JsonKey(name: 'employee_id') required String employeeId,
    @JsonKey(name: 'account_status') required String accountStatus,
    @JsonKey(name: 'enrolment_status') required String enrolmentStatus,
  }) = _StaffMember;

  factory StaffMember.fromJson(Map<String, dynamic> json) =>
      _$StaffMemberFromJson(json);
}
