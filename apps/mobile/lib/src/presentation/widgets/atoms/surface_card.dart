import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? AppBrand.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppBrand.border),
    ),
    child: child,
  );
}
