import 'package:freezed_annotation/freezed_annotation.dart';

part 'attendance_receipt.freezed.dart';
part 'attendance_receipt.g.dart';

@freezed
abstract class AttendanceReceipt with _$AttendanceReceipt {
  const factory AttendanceReceipt({
    required String id,
    @JsonKey(name: 'recorded_at') required DateTime recordedAt,
    @JsonKey(name: 'attendance_date') required String attendanceDate,
    required String timezone,
    @JsonKey(readValue: _latitude) required double latitude,
    @JsonKey(readValue: _longitude) required double longitude,
    @JsonKey(readValue: _accuracy) required double accuracy,
  }) = _AttendanceReceipt;

  factory AttendanceReceipt.fromJson(Map<String, dynamic> json) =>
      _$AttendanceReceiptFromJson(json);
}

Object? _latitude(Map<dynamic, dynamic> json, String key) =>
    (json['location'] as Map<String, dynamic>)['latitude'];
Object? _longitude(Map<dynamic, dynamic> json, String key) =>
    (json['location'] as Map<String, dynamic>)['longitude'];
Object? _accuracy(Map<dynamic, dynamic> json, String key) =>
    (json['location'] as Map<String, dynamic>)['accuracy_m'];
