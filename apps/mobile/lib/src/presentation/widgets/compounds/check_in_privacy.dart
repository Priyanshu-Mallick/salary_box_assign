import 'package:attendance_mobile/src/presentation/widgets/atoms/surface_card.dart';
import 'package:attendance_mobile/src/presentation/widgets/molecules/privacy_point.dart';
import 'package:flutter/material.dart';

class CheckInPrivacy extends StatelessWidget {
  const CheckInPrivacy({super.key});

  @override
  Widget build(BuildContext context) => const SurfaceCard(
    child: Column(
      children: [
        PrivacyPoint(
          icon: Icons.camera_alt_outlined,
          text: 'A fresh selfie verifies your identity',
        ),
        SizedBox(height: 16),
        PrivacyPoint(
          icon: Icons.location_on_outlined,
          text: 'Precise location confirms check-in context',
        ),
        SizedBox(height: 16),
        PrivacyPoint(
          icon: Icons.lock_outline_rounded,
          text: 'Evidence is encrypted and access controlled',
        ),
      ],
    ),
  );
}
