import 'dart:async';

import 'package:attendance_mobile/src/domain/models/api_failure.dart';
import 'package:attendance_mobile/src/domain/models/staff_member.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/admin_state.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef CaptureEnrolmentPhoto = Future<String?> Function(int index);

final adminViewModelProvider = NotifierProvider<AdminViewModel, AdminState>(
  AdminViewModel.new,
);

class AdminViewModel extends Notifier<AdminState> {
  @override
  AdminState build() {
    unawaited(Future.microtask(loadStaff));
    return const AdminState(loading: true);
  }

  Future<void> loadStaff() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await ref.read(staffRepositoryProvider).list();
      state = state.copyWith(staff: items, loading: false);
    } on ApiFailure catch (error) {
      state = state.copyWith(loading: false, error: error.message);
    }
  }

  void search(String query) => state = state.copyWith(query: query);

  Future<StaffMember?> create(String name, String employeeId) async {
    state = state.copyWith(saving: true, error: null);
    try {
      final item = await ref
          .read(staffRepositoryProvider)
          .create(name.trim(), employeeId.trim());
      state = state.copyWith(
        saving: false,
        staff: [...state.staff, item],
        selected: item,
      );
      return item;
    } on ApiFailure catch (error) {
      state = state.copyWith(saving: false, error: error.message);
      return null;
    }
  }

  Future<void> select(String id) async {
    final cached = state.staff.where((item) => item.id == id).firstOrNull;
    if (cached != null) state = state.copyWith(selected: cached, error: null);
    try {
      final item = await ref.read(staffRepositoryProvider).get(id);
      state = state.copyWith(selected: item, error: null);
    } on ApiFailure catch (error) {
      state = state.copyWith(error: error.message);
    }
  }

  Future<bool> enrol(StaffMember staff, CaptureEnrolmentPhoto capture) async {
    final paths = <String>[];
    state = state.copyWith(saving: true, error: null);
    try {
      for (var index = 0; index < 3; index++) {
        final path = await capture(index);
        if (path == null) return false;
        paths.add(path);
      }
      await ref.read(staffRepositoryProvider).enrol(staff.id, paths);
      await _refreshSelected(staff.id);
      await loadStaff();
      return true;
    } on ApiFailure catch (error) {
      state = state.copyWith(error: error.message);
      return false;
    } finally {
      await ref.read(deviceCaptureServiceProvider).deleteFiles(paths);
      state = state.copyWith(saving: false);
    }
  }

  Future<void> _refreshSelected(String id) async {
    final item = await ref.read(staffRepositoryProvider).get(id);
    state = state.copyWith(selected: item);
  }
}
