import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/camera_view_model.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/brand_backdrop.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/camera_controls.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/camera_viewfinder.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraCaptureView extends StatefulWidget {
  const CameraCaptureView({
    super.key,
    required this.title,
    required this.guidance,
  });
  final String title;
  final String guidance;

  @override
  State<CameraCaptureView> createState() => _CameraCaptureViewState();
}

class _CameraCaptureViewState extends State<CameraCaptureView>
    with WidgetsBindingObserver {
  late final CameraViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel = CameraViewModel()..initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _viewModel.pause();
    } else if (state == AppLifecycleState.resumed) {
      _viewModel.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _viewModel,
    builder: (context, _) {
      final state = _viewModel.state;
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: BrandBackdrop(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.face_retouching_natural_rounded,
                        color: AppBrand.mint,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(widget.guidance)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: state.error != null
                        ? _CameraError(
                            message: state.error!,
                            onRetry: _viewModel.initialize,
                          )
                        : state.initializing || state.controller == null
                        ? const Center(child: CircularProgressIndicator())
                        : CameraViewfinder(controller: state.controller!),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                  child: CameraControls(
                    capturing: state.capturing,
                    onCapture: state.controller == null ? null : _capture,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _capture() async {
    final path = await _viewModel.capture();
    if (path == null) return;

    // Enrollment opens a new capture route immediately after this one closes.
    // Release the native camera session first so the next preview can acquire it.
    await _viewModel.pause();
    if (mounted) Navigator.pop(context, path);
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            size: 48,
            color: AppBrand.danger,
          ),
          const SizedBox(height: 16),
          Text(
            'Camera unavailable',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: openAppSettings,
                child: const Text('Settings'),
              ),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ],
      ),
    ),
  );
}
