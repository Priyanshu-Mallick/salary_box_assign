import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:attendance_mobile/src/domain/models/staff_member.dart';
import 'package:attendance_mobile/src/presentation/widgets/atoms/status_pill.dart';
import 'package:flutter/material.dart';

class StaffCard extends StatelessWidget {
  const StaffCard({super.key, required this.item, required this.onTap});
  final StaffMember item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppBrand.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppBrand.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _Avatar(name: item.name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(item.employeeId, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            StatusPill(
              label: item.enrolmentStatus.replaceAll('_', ' ').toUpperCase(),
              active: item.enrolmentStatus == 'active',
            ),
            const Icon(Icons.chevron_right_rounded, color: AppBrand.muted),
          ],
        ),
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF263C46), Color(0xFF292343)],
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      name.characters.first.toUpperCase(),
      style: const TextStyle(
        color: AppBrand.mint,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
