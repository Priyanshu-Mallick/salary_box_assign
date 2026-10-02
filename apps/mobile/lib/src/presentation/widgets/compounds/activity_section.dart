import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:attendance_mobile/src/domain/models/attendance_receipt.dart';
import 'package:attendance_mobile/src/presentation/widgets/atoms/surface_card.dart';
import 'package:attendance_mobile/src/presentation/widgets/molecules/receipt_card.dart';
import 'package:attendance_mobile/src/presentation/widgets/molecules/screen_state.dart';
import 'package:flutter/material.dart';

class ActivitySection extends StatelessWidget {
  const ActivitySection({
    super.key,
    required this.items,
    required this.loading,
  });
  final List<AttendanceReceipt> items;
  final bool loading;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Recent activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Text(
            'PULL TO REFRESH',
            style: TextStyle(
              color: AppBrand.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
      const SizedBox(height: 13),
      if (loading)
        const Padding(
          padding: EdgeInsets.all(36),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (items.isEmpty)
        const SurfaceCard(
          child: ScreenState(
            icon: Icons.history_toggle_off_rounded,
            title: 'No check-ins yet',
            message: 'Your verified attendance will appear here.',
          ),
        )
      else
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ReceiptCard(receipt: item),
          ),
        ),
    ],
  );
}
