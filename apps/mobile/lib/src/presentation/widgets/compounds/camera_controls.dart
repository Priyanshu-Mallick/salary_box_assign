import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class CameraControls extends StatelessWidget {
  const CameraControls({
    super.key,
    required this.capturing,
    required this.onCapture,
  });
  final bool capturing;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        button: true,
        label: 'Capture face photo',
        child: GestureDetector(
          onTap: capturing ? null : onCapture,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: capturing ? AppBrand.muted : AppBrand.mint,
                width: 3,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: capturing ? AppBrand.surfaceHigh : AppBrand.mint,
                shape: BoxShape.circle,
              ),
              child: capturing
                  ? const Padding(
                      padding: EdgeInsets.all(17),
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      color: AppBrand.ink,
                      size: 28,
                    ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 11),
      const Text(
        'Keep still and tap to capture',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );
}
