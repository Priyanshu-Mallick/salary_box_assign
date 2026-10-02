import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:attendance_mobile/src/domain/models/attendance_receipt.dart';
import 'package:attendance_mobile/src/presentation/widgets/atoms/status_pill.dart';
import 'package:attendance_mobile/src/presentation/widgets/atoms/surface_card.dart';
import 'package:flutter/material.dart';

class ReceiptCard extends StatelessWidget {
  const ReceiptCard({super.key, required this.receipt});
  final AttendanceReceipt receipt;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(17),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppBrand.success.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppBrand.success,
            size: 23,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: _Details(receipt: receipt)),
      ],
    ),
  );
}

class _Details extends StatelessWidget {
  const _Details({required this.receipt});
  final AttendanceReceipt receipt;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              _displayDate(receipt.attendanceDate),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const StatusPill(label: 'VERIFIED', active: true),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        '${_displayTime(receipt.recordedAt)} · ${receipt.timezone}',
        style: const TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 3),
      Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 14,
            color: AppBrand.muted,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${receipt.latitude.toStringAsFixed(4)}, '
              '${receipt.longitude.toStringAsFixed(4)} · '
              '±${receipt.accuracy.round()} m',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    ],
  );
}

String _displayDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
}

String _displayTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
      ? local.hour - 12
      : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
}
