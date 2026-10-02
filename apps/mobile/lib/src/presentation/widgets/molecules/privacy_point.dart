import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PrivacyPoint extends StatelessWidget {
  const PrivacyPoint({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppBrand.surfaceHigh,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 18, color: AppBrand.mint),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(color: AppBrand.text, fontSize: 13),
        ),
      ),
    ],
  );
}
