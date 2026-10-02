import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 44, this.showWordmark = true});
  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CustomPaint(size: Size.square(size), painter: _LogoPainter()),
      if (showWordmark) ...[
        const SizedBox(width: 12),
        Text(
          AppBrand.name.toUpperCase(),
          style: TextStyle(
            color: AppBrand.text,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            letterSpacing: size * 0.055,
          ),
        ),
      ],
    ],
  );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppBrand.mint, AppBrand.violet],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.28)),
      background,
    );
    final mark = Paint()
      ..color = AppBrand.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.105
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.52)
      ..lineTo(size.width * 0.43, size.height * 0.70)
      ..lineTo(size.width * 0.77, size.height * 0.30);
    canvas.drawPath(path, mark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
