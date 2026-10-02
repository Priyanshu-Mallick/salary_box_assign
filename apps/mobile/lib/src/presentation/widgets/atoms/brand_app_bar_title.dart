import 'package:attendance_mobile/src/presentation/widgets/atoms/brand_logo.dart';
import 'package:flutter/material.dart';

class BrandAppBarTitle extends StatelessWidget {
  const BrandAppBarTitle({super.key, required this.section});
  final String section;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const BrandLogo(size: 32, showWordmark: false),
      const SizedBox(width: 12),
      Text(section),
    ],
  );
}
