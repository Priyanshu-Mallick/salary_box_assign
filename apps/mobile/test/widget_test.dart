import 'package:attendance_mobile/src/core/theme/app_theme.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/auth_state.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/auth_view_model.dart';
import 'package:attendance_mobile/src/presentation/views/login_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedOutAuthViewModel extends AuthViewModel {
  @override
  AuthState build() => const AuthState(loading: false);
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
    await loader.load();
  });

  Future<void> pumpLogin(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(_SignedOutAuthViewModel.new),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const LoginView()),
      ),
    );
    await tester.pump();
  }

  testWidgets('login screen exposes credentials and submit action', (
    tester,
  ) async {
    await pumpLogin(tester, const Size(390, 844));

    expect(find.text('NEXA'), findsOneWidget);
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign in securely'), findsOneWidget);
  });

  testWidgets('login layout remains usable on a narrow phone', (tester) async {
    await pumpLogin(tester, const Size(320, 640));

    expect(tester.takeException(), isNull);
    expect(find.text('Welcome back.'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in securely').hitTestable(), findsOneWidget);
  });
}
