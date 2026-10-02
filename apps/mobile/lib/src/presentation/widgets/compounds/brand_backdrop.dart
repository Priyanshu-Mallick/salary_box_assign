import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppBrand.canvas,
      gradient: RadialGradient(
        center: Alignment(0.85, -0.9),
        radius: 1.15,
        colors: [Color(0x332C5A56), AppBrand.canvas],
        stops: [0, 0.72],
      ),
    ),
    child: child,
  );
}
