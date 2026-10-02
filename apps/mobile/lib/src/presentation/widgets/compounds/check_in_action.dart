import 'package:attendance_mobile/src/presentation/viewmodels/attendance_state.dart';
import 'package:flutter/material.dart';

class CheckInAction extends StatelessWidget {
  const CheckInAction({
    super.key,
    required this.state,
    required this.onStart,
    required this.onSettings,
    required this.onDone,
  });
  final AttendanceState state;
  final VoidCallback onStart;
  final VoidCallback onSettings;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => switch (state.step) {
    AttendanceStep.ready || AttendanceStep.failure => FilledButton.icon(
      onPressed: onStart,
      icon: Icon(
        state.step == AttendanceStep.failure
            ? Icons.refresh_rounded
            : Icons.arrow_forward_rounded,
      ),
      label: Text(
        state.step == AttendanceStep.failure
            ? 'Try check-in again'
            : 'Continue securely',
      ),
    ),
    AttendanceStep.permission => FilledButton.icon(
      onPressed: onSettings,
      icon: const Icon(Icons.settings_outlined),
      label: const Text('Open app settings'),
    ),
    AttendanceStep.success => FilledButton.icon(
      onPressed: onDone,
      icon: const Icon(Icons.check_rounded),
      label: const Text('Back to workspace'),
    ),
    _ => const Column(
      children: [
        LinearProgressIndicator(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        SizedBox(height: 12),
        Text('Keep this screen open', style: TextStyle(fontSize: 12)),
      ],
    ),
  };
}
