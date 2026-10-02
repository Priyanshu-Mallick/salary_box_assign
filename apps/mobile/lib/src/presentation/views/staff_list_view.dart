import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/admin_view_model.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/auth_view_model.dart';
import 'package:attendance_mobile/src/presentation/widgets/atoms/brand_app_bar_title.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/brand_backdrop.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/team_directory.dart';
import 'package:attendance_mobile/src/presentation/widgets/molecules/metric_card.dart';
import 'package:attendance_mobile/src/presentation/widgets/molecules/screen_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StaffListView extends ConsumerStatefulWidget {
  const StaffListView({super.key});

  @override
  ConsumerState<StaffListView> createState() => _StaffListViewState();
}

class _StaffListViewState extends ConsumerState<StaffListView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminViewModelProvider);
    final viewModel = ref.read(adminViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(section: 'Team'),
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
          onRefresh: viewModel.loadStaff,
          child: state.loading && state.staff.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.error != null && state.staff.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    ScreenState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load your team',
                      message: state.error!,
                      actionLabel: 'Try again',
                      onAction: viewModel.loadStaff,
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                  children: [
                    Text(
                      'Your people,\nat a glance.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: MetricCard(
                            label: 'TEAM SIZE',
                            value: '${state.staff.length}',
                            icon: Icons.groups_2_outlined,
                            color: AppBrand.violet,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MetricCard(
                            label: 'ENROLLED',
                            value: '${state.enrolledCount}',
                            icon: Icons.face_retouching_natural_rounded,
                            color: AppBrand.mint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _search,
                      onChanged: viewModel.search,
                      decoration: InputDecoration(
                        hintText: 'Search people or employee ID',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: state.query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    TeamDirectory(
                      items: state.visibleStaff,
                      query: state.query,
                      onOpen: (id) => context.push('/admin/staff/$id'),
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/staff/new'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add person'),
      ),
    );
  }

  void _clearSearch() {
    _search.clear();
    ref.read(adminViewModelProvider.notifier).search('');
  }
}
