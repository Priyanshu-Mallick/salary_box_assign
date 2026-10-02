import 'package:attendance_mobile/src/domain/models/app_user.dart';
import 'package:attendance_mobile/src/domain/models/attendance_receipt.dart';
import 'package:attendance_mobile/src/domain/models/staff_member.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/admin_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Freezed user schema maps snake-case API fields', () {
    final user = AppUser.fromJson({
      'id': 'user-1',
      'role': 'staff',
      'display_name': 'Aisha Verma',
      'timezone': 'Asia/Kolkata',
      'staff_id': 'staff-1',
      'enrolment_status': 'active',
    });

    expect(user.role, UserRole.staff);
    expect(user.displayName, 'Aisha Verma');
    expect(user.copyWith(displayName: 'Aisha V.').displayName, 'Aisha V.');
  });

  test('Freezed attendance schema reads nested location', () {
    final receipt = AttendanceReceipt.fromJson({
      'id': 'attendance-1',
      'recorded_at': '2026-10-01T09:42:00Z',
      'attendance_date': '2026-10-01',
      'timezone': 'Asia/Kolkata',
      'location': {
        'latitude': 19.076,
        'longitude': 72.8777,
        'accuracy_m': 12.0,
      },
    });

    expect(receipt.latitude, 19.076);
    expect(receipt.accuracy, 12);
  });

  test('admin view state owns filtering and enrolment metrics', () {
    const items = [
      StaffMember(
        id: '1',
        name: 'Aisha Verma',
        employeeId: 'NXA-2048',
        accountStatus: 'active',
        enrolmentStatus: 'active',
      ),
      StaffMember(
        id: '2',
        name: 'Noah Williams',
        employeeId: 'NXA-2051',
        accountStatus: 'pending',
        enrolmentStatus: 'not_enrolled',
      ),
    ];
    const state = AdminState(staff: items, query: '2051');

    expect(state.visibleStaff.single.name, 'Noah Williams');
    expect(state.enrolledCount, 1);
  });
}
