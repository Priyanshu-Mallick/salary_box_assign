import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:attendance_mobile/src/domain/models/staff_member.dart';
import 'package:attendance_mobile/src/presentation/widgets/atoms/status_pill.dart';
import 'package:attendance_mobile/src/presentation/widgets/atoms/surface_card.dart';
import 'package:flutter/material.dart';

class ProfileSummary extends StatelessWidget {
  const ProfileSummary({super.key, required this.staff});
  final StaffMember staff;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SurfaceCard(
        child: Column(
          children: [
            _ProfileAvatar(name: staff.name),
            const SizedBox(height: 18),
            Text(staff.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 5),
            Text(
              staff.employeeId,
              style: const TextStyle(
                color: AppBrand.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _StatusRow(
              icon: Icons.account_circle_outlined,
              label: 'Login account',
              value: staff.accountStatus,
            ),
            const Divider(),
            _StatusRow(
              icon: Icons.face_retouching_natural_rounded,
              label: 'Face enrolment',
              value: staff.enrolmentStatus,
            ),
          ],
        ),
      ),
    ],
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: 82,
    height: 82,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF284B4B), Color(0xFF332A57)],
      ),
      borderRadius: BorderRadius.circular(26),
    ),
    child: Text(
      name.characters.first.toUpperCase(),
      style: const TextStyle(
        color: AppBrand.mint,
        fontSize: 32,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final active = value == 'active' || value == 'provisioned';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppBrand.surfaceHigh,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, size: 20, color: AppBrand.muted),
      ),
      title: Text(label),
      trailing: StatusPill(
        label: value.replaceAll('_', ' ').toUpperCase(),
        active: active,
      ),
    );
  }
}
