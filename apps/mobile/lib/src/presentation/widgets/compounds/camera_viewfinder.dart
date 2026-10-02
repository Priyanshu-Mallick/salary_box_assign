import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraViewfinder extends StatelessWidget {
  const CameraViewfinder({super.key, required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final preview = controller.value.previewSize;
    if (preview == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: preview.height,
                  height: preview.width,
                  child: CameraPreview(controller),
                ),
              ),
            ),
            const IgnorePointer(
              child: CustomPaint(painter: FaceGuidePainter()),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(child: _PositionLabel()),
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionLabel extends StatelessWidget {
  const _PositionLabel();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(
      color: AppBrand.ink.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Colors.white24),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.face_rounded, color: AppBrand.mint, size: 16),
        SizedBox(width: 7),
        Text(
          'POSITION YOUR FACE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
      ],
    ),
  );
}

class FaceGuidePainter extends CustomPainter {
  const FaceGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final oval = Rect.fromCenter(
      center: center,
      width: size.width * 0.70,
      height: size.height * 0.58,
    );
    final mask = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      mask,
      Paint()..color = Colors.black.withValues(alpha: 0.48),
    );
    canvas.drawOval(
      oval,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    final scanY = oval.top + oval.height * 0.56;
    canvas.drawLine(
      Offset(oval.left + 22, scanY),
      Offset(oval.right - 22, scanY),
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.transparent, AppBrand.mint, Colors.transparent],
        ).createShader(Rect.fromLTRB(oval.left, scanY, oval.right, scanY + 2))
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
