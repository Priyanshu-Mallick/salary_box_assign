import 'package:attendance_mobile/src/presentation/viewmodels/attendance_presentation.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/attendance_state.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/attendance_view_model.dart';
import 'package:attendance_mobile/src/presentation/views/camera_capture_view.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/brand_backdrop.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/check_in_privacy.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/check_in_action.dart';
import 'package:attendance_mobile/src/presentation/widgets/molecules/receipt_card.dart';
import 'package:attendance_mobile/src/presentation/widgets/molecules/step_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AttendanceView extends ConsumerWidget {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceViewModelProvider);
    final viewModel = ref.read(attendanceViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Secure check-in')),
      body: BrandBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StepProgress(activeIndex: state.progressIndex),
                const SizedBox(height: 32),
                Expanded(child: _CheckInBody(state: state)),
                const SizedBox(height: 18),
                CheckInAction(
                  state: state,
                  onStart: () => viewModel.checkIn(() => _capture(context)),
                  onSettings: viewModel.openSettings,
                  onDone: () => context.go('/staff/home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _capture(BuildContext context) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const CameraCaptureView(
            title: 'Attendance selfie',
            guidance: 'Center your face and look directly at the camera.',
          ),
        ),
      );
}

class _CheckInBody extends StatelessWidget {
  const _CheckInBody({required this.state});
  final AttendanceState state;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: state.stateColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: state.stateColor.withValues(alpha: 0.28)),
          ),
          child: Icon(state.icon, size: 43, color: state.stateColor),
        ),
        const SizedBox(height: 26),
        Text(
          state.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(state.description, textAlign: TextAlign.center),
        if (state.receipt != null) ...[
          const SizedBox(height: 26),
          ReceiptCard(receipt: state.receipt!),
        ] else if (state.step == AttendanceStep.ready) ...[
          const SizedBox(height: 30),
          const CheckInPrivacy(),
        ],
      ],
    ),
  );
}
