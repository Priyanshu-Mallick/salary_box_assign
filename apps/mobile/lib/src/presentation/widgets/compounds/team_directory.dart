import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:attendance_mobile/src/domain/models/staff_member.dart';
import 'package:attendance_mobile/src/presentation/widgets/molecules/screen_state.dart';
import 'package:attendance_mobile/src/presentation/widgets/molecules/staff_card.dart';
import 'package:flutter/material.dart';

class TeamDirectory extends StatelessWidget {
  const TeamDirectory({
    super.key,
    required this.items,
    required this.query,
    required this.onOpen,
  });
  final List<StaffMember> items;
  final String query;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Team directory',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Text(
            '${items.length} ${items.length == 1 ? 'person' : 'people'}',
            style: const TextStyle(
              color: AppBrand.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (items.isEmpty)
        ScreenState(
          icon: query.trim().isEmpty
              ? Icons.group_add_outlined
              : Icons.search_off_rounded,
          title: query.trim().isEmpty ? 'Build your team' : 'No matches found',
          message: query.trim().isEmpty
              ? 'Add the first staff member to begin secure enrolment.'
              : 'Try another name or employee ID.',
        )
      else
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StaffCard(item: item, onTap: () => onOpen(item.id)),
          ),
        ),
    ],
  );
}
