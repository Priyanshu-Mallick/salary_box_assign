import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/attendance_view_model.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/auth_view_model.dart';
import 'package:attendance_mobile/src/presentation/widgets/atoms/brand_app_bar_title.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/activity_section.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/brand_backdrop.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/check_in_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StaffHomeView extends ConsumerWidget {
  const StaffHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authViewModelProvider).user;
    final attendance = ref.watch(attendanceViewModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(section: 'My workspace'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: ref.read(authViewModelProvider.notifier).logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BrandBackdrop(
        child: RefreshIndicator(
          onRefresh: ref.read(attendanceViewModelProvider.notifier).loadHistory,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              Text(
                'Good ${_dayPeriod()},',
                style: const TextStyle(
                  color: AppBrand.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                user?.displayName ?? 'Team member',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 24),
              CheckInCard(
                enrolmentStatus: user?.enrolmentStatus ?? 'unknown',
                onCheckIn: () => context.push('/staff/attendance'),
              ),
              const SizedBox(height: 30),
              ActivitySection(
                items: attendance.history,
                loading: attendance.loadingHistory,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dayPeriod() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}
