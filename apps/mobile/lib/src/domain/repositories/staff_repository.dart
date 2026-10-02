import 'package:attendance_mobile/src/domain/models/api_failure.dart';
import 'package:attendance_mobile/src/domain/models/staff_member.dart';
import 'package:attendance_mobile/src/domain/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

abstract interface class StaffRepository {
  Future<List<StaffMember>> list();
  Future<StaffMember> get(String id);
  Future<StaffMember> create(String name, String employeeId);
  Future<void> enrol(String staffId, List<String> imagePaths);
}

class RestStaffRepository implements StaffRepository {
  RestStaffRepository(this._api, {Uuid uuid = const Uuid()}) : _uuid = uuid;
  final ApiService _api;
  final Uuid _uuid;

  @override
  Future<List<StaffMember>> list() async {
    final data = await _api.request<Map<String, dynamic>>('GET', '/staff');
    return (data['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(StaffMember.fromJson)
        .toList(growable: false);
  }

  @override
  Future<StaffMember> get(String id) async => StaffMember.fromJson(
    await _api.request<Map<String, dynamic>>('GET', '/staff/$id'),
  );

  @override
  Future<StaffMember> create(String name, String employeeId) async {
    final data = await _api.request<Map<String, dynamic>>(
      'POST',
      '/staff',
      data: {'name': name, 'employee_id': employeeId},
      headers: {'Idempotency-Key': _uuid.v4()},
    );
    return StaffMember.fromJson(data);
  }

  @override
  Future<void> enrol(String staffId, List<String> imagePaths) async {
    if (imagePaths.length != 3) {
      throw const ApiFailure(
        'INVALID_IMAGE_COUNT',
        'Capture exactly three images.',
      );
    }
    final form = FormData.fromMap({
      for (var index = 0; index < imagePaths.length; index++)
        'image_${index + 1}': MultipartFile.fromFileSync(
          imagePaths[index],
          filename: 'enrolment-${index + 1}.jpg',
          contentType: DioMediaType.parse('image/jpeg'),
        ),
    });
    await _api.request<Map<String, dynamic>>(
      'POST',
      '/staff/$staffId/face-enrolments',
      data: form,
    );
  }
}
