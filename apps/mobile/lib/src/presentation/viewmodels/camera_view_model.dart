import 'package:attendance_mobile/src/presentation/viewmodels/camera_state.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraViewModel extends ChangeNotifier {
  CameraState _state = const CameraState();
  bool _disposed = false;
  int _generation = 0;
  CameraState get state => _state;

  Future<void> initialize() async {
    final generation = ++_generation;
    _set(_state.copyWith(initializing: true, error: null));
    final status = await Permission.camera.request();
    if (generation != _generation || _disposed) return;
    if (!status.isGranted) {
      _set(
        _state.copyWith(
          initializing: false,
          error: status.isPermanentlyDenied
              ? 'Camera permission is disabled. Open Settings to continue.'
              : 'Camera permission is required to capture your face.',
        ),
      );
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _set(
          _state.copyWith(
            initializing: false,
            error: 'No camera is available on this device.',
          ),
        );
        return;
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (_disposed || generation != _generation) {
        await controller.dispose();
        return;
      }
      _set(_state.copyWith(controller: controller, initializing: false));
    } on CameraException catch (error) {
      if (generation != _generation || _disposed) return;
      _set(
        _state.copyWith(
          initializing: false,
          error: error.description ?? 'Camera could not start.',
        ),
      );
    }
  }

  Future<void> pause() async {
    _generation++;
    final controller = _state.controller;
    _set(_state.copyWith(controller: null));
    await controller?.dispose();
  }

  Future<void> resume() async {
    if (_state.controller == null) await initialize();
  }

  Future<String?> capture() async {
    final controller = _state.controller;
    if (controller == null || _state.capturing) return null;
    _set(_state.copyWith(capturing: true, error: null));
    try {
      return (await controller.takePicture()).path;
    } on CameraException catch (error) {
      _set(
        _state.copyWith(error: error.description ?? 'Photo capture failed.'),
      );
      return null;
    } finally {
      _set(_state.copyWith(capturing: false));
    }
  }

  void _set(CameraState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _state.controller?.dispose();
    super.dispose();
  }
}
