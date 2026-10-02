import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:attendance_mobile/src/presentation/widgets/atoms/status_pill.dart';
import 'package:flutter/material.dart';

class CheckInCard extends StatelessWidget {
  const CheckInCard({
    super.key,
    required this.enrolmentStatus,
    required this.onCheckIn,
  });
  final String enrolmentStatus;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A403B), Color(0xFF1C1938)],
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFF31534F)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppBrand.mint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                color: AppBrand.mint,
              ),
            ),
            StatusPill(
              label: enrolmentStatus.toUpperCase(),
              active: enrolmentStatus == 'active',
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'Ready to check in?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 7),
        const Text('Verify your face and location in one secure step.'),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: enrolmentStatus == 'active' ? onCheckIn : null,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Start check-in'),
        ),
      ],
    ),
  );
}
