import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:attendance_mobile/src/domain/models/staff_member.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/admin_view_model.dart';
import 'package:attendance_mobile/src/presentation/views/camera_capture_view.dart';
import 'package:attendance_mobile/src/presentation/widgets/atoms/surface_card.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/brand_backdrop.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/profile_summary.dart';
import 'package:attendance_mobile/src/presentation/widgets/molecules/screen_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StaffProfileView extends ConsumerStatefulWidget {
  const StaffProfileView({super.key, required this.id});
  final String id;

  @override
  ConsumerState<StaffProfileView> createState() => _StaffProfileViewState();
}

class _StaffProfileViewState extends ConsumerState<StaffProfileView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(adminViewModelProvider.notifier).select(widget.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminViewModelProvider);
    final staff = state.selected?.id == widget.id ? state.selected : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Staff profile')),
      body: BrandBackdrop(
        child: staff == null
            ? state.error == null
                  ? const Center(child: CircularProgressIndicator())
                  : ScreenState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Profile unavailable',
                      message: state.error!,
                      actionLabel: 'Try again',
                      onAction: () => ref
                          .read(adminViewModelProvider.notifier)
                          .select(widget.id),
                    )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                children: [
                  ProfileSummary(staff: staff),
                  const SizedBox(height: 16),
                  const SurfaceCard(
                    color: Color(0xFF111A22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.privacy_tip_outlined, color: AppBrand.sky),
                        SizedBox(width: 13),
                        Expanded(
                          child: Text(
                            'Face data is sensitive. Confirm this person has reviewed and accepted the privacy notice.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.error!,
                      style: const TextStyle(color: AppBrand.danger),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: state.saving ? null : () => _confirm(staff),
                    icon: const Icon(Icons.face_retouching_natural_rounded),
                    label: Text(
                      state.saving
                          ? 'Submitting…'
                          : staff.enrolmentStatus == 'active'
                          ? 'Replace enrolment'
                          : 'Enrol face',
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _confirm(StaffMember staff) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm consent'),
        content: Text(
          '${staff.name} has read the privacy notice and consents to face enrolment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await ref.read(adminViewModelProvider.notifier).enrol(staff, _capture);
  }

  Future<String?> _capture(int index) => Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => CameraCaptureView(
        title: 'Enrolment photo ${index + 1} of 3',
        guidance: 'Center your face, look forward, and use even lighting.',
      ),
    ),
  );
}
