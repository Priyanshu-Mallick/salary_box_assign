import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:attendance_mobile/src/core/theme/app_theme.dart';
import 'package:attendance_mobile/src/domain/models/app_user.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/auth_view_model.dart';
import 'package:attendance_mobile/src/presentation/views/add_staff_view.dart';
import 'package:attendance_mobile/src/presentation/views/attendance_view.dart';
import 'package:attendance_mobile/src/presentation/views/login_view.dart';
import 'package:attendance_mobile/src/presentation/views/staff_home_view.dart';
import 'package:attendance_mobile/src/presentation/views/staff_list_view.dart';
import 'package:attendance_mobile/src/presentation/views/staff_profile_view.dart';
import 'package:attendance_mobile/src/presentation/widgets/atoms/brand_logo.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/brand_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authViewModelProvider);
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (auth.loading) {
        return state.matchedLocation == '/loading' ? null : '/loading';
      }
      final user = auth.user;
      if (user == null) {
        return state.matchedLocation == '/login' ? null : '/login';
      }
      if (state.matchedLocation == '/login' ||
          state.matchedLocation == '/loading') {
        return user.role == UserRole.admin ? '/admin/staff' : '/staff/home';
      }
      if (user.role == UserRole.staff &&
          state.matchedLocation.startsWith('/admin')) {
        return '/staff/home';
      }
      if (user.role == UserRole.admin &&
          state.matchedLocation.startsWith('/staff/')) {
        return '/admin/staff';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/loading', builder: (_, _) => const _LoadingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginView()),
      GoRoute(path: '/admin/staff', builder: (_, _) => const StaffListView()),
      GoRoute(
        path: '/admin/staff/new',
        builder: (_, _) => const AddStaffView(),
      ),
      GoRoute(
        path: '/admin/staff/:id',
        builder: (_, state) =>
            StaffProfileView(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/staff/home', builder: (_, _) => const StaffHomeView()),
      GoRoute(
        path: '/staff/attendance',
        builder: (_, _) => const AttendanceView(),
      ),
    ],
  );
});

class AttendanceApp extends ConsumerWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: BrandBackdrop(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(size: 58),
            SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                semanticsLabel: 'Restoring session',
              ),
            ),
            SizedBox(height: 14),
            Text('Securing your workspace…'),
          ],
        ),
      ),
    ),
  );
}
