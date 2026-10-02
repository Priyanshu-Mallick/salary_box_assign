import 'dart:io';

import 'package:attendance_mobile/src/domain/models/api_failure.dart';
import 'package:attendance_mobile/src/domain/models/attendance_submission.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

class DeviceCaptureService {
  Future<LocationSnapshot> prepare() async {
    final statuses = await [
      permissions.Permission.locationWhenInUse,
      permissions.Permission.camera,
    ].request();
    if (statuses.values.any((status) => !status.isGranted)) {
      throw const ApiFailure(
        'PERMISSION_REQUIRED',
        'Grant camera and precise location permission in Settings, then try again.',
      );
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiFailure(
        'LOCATION_DISABLED',
        'Turn on location services and try again.',
      );
    }
    return currentLocation();
  }

  Future<LocationSnapshot> currentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (position.accuracy > 100) {
      throw ApiFailure(
        'LOCATION_INACCURATE',
        'Location accuracy is ${position.accuracy.round()} m. Move to an open area and try again.',
      );
    }
    return LocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      isMocked: position.isMocked,
      capturedAt: position.timestamp,
    );
  }

  Future<void> deleteFiles(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        await File(path).delete();
      } on FileSystemException {
        // Temporary camera files may already have been reclaimed by the OS.
      }
    }
  }

  Future<void> openSettings() => permissions.openAppSettings();
}
