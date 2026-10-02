import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

enum UserRole { admin, staff }

@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required UserRole role,
    @JsonKey(name: 'display_name') required String displayName,
    required String timezone,
    @JsonKey(name: 'staff_id') String? staffId,
    @JsonKey(name: 'enrolment_status') String? enrolmentStatus,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}
