import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const colors = ColorScheme.dark(
    primary: AppBrand.mint,
    onPrimary: AppBrand.ink,
    secondary: AppBrand.violet,
    onSecondary: AppBrand.text,
    surface: AppBrand.surface,
    onSurface: AppBrand.text,
    error: AppBrand.danger,
    onError: AppBrand.ink,
    outline: AppBrand.border,
  );
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'Manrope',
    colorScheme: colors,
    scaffoldBackgroundColor: AppBrand.canvas,
  );
  return base.copyWith(
    textTheme: _textTheme(base.textTheme),
    appBarTheme: _appBarTheme,
    cardTheme: _cardTheme,
    inputDecorationTheme: _inputTheme,
    filledButtonTheme: FilledButtonThemeData(style: _filledButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedButtonStyle),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppBrand.mint,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppBrand.mint,
      foregroundColor: AppBrand.ink,
      elevation: 4,
      extendedTextStyle: TextStyle(fontWeight: FontWeight.w800),
    ),
    dividerTheme: const DividerThemeData(color: AppBrand.border, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppBrand.mint,
      linearTrackColor: AppBrand.surfaceHigh,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppBrand.surfaceHigh,
      contentTextStyle: const TextStyle(color: AppBrand.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppBrand.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

TextTheme _textTheme(TextTheme base) => base.copyWith(
  displaySmall: base.displaySmall?.copyWith(
    fontWeight: FontWeight.w800,
    height: 1.08,
    letterSpacing: -1.2,
  ),
  headlineLarge: base.headlineLarge?.copyWith(
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.8,
  ),
  headlineMedium: base.headlineMedium?.copyWith(
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.6,
  ),
  headlineSmall: base.headlineSmall?.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  ),
  titleLarge: base.titleLarge?.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  ),
  titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  bodyLarge: base.bodyLarge?.copyWith(height: 1.55, color: AppBrand.text),
  bodyMedium: base.bodyMedium?.copyWith(height: 1.5, color: AppBrand.muted),
  labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
);

const _appBarTheme = AppBarTheme(
  backgroundColor: Colors.transparent,
  foregroundColor: AppBrand.text,
  elevation: 0,
  scrolledUnderElevation: 0,
  titleTextStyle: TextStyle(
    fontFamily: 'Manrope',
    color: AppBrand.text,
    fontSize: 19,
    fontWeight: FontWeight.w700,
  ),
);

final _cardTheme = CardThemeData(
  color: AppBrand.surface,
  elevation: 0,
  margin: EdgeInsets.zero,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(22),
    side: const BorderSide(color: AppBrand.border),
  ),
);

final _inputTheme = InputDecorationTheme(
  filled: true,
  fillColor: AppBrand.surface,
  labelStyle: const TextStyle(color: AppBrand.muted),
  hintStyle: const TextStyle(color: AppBrand.muted),
  prefixIconColor: AppBrand.muted,
  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
  border: _inputBorder(AppBrand.border),
  enabledBorder: _inputBorder(AppBrand.border),
  focusedBorder: _inputBorder(AppBrand.mint, width: 1.5),
  errorBorder: _inputBorder(AppBrand.danger),
);

OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

final _filledButtonStyle = FilledButton.styleFrom(
  backgroundColor: AppBrand.mint,
  foregroundColor: AppBrand.ink,
  disabledBackgroundColor: AppBrand.surfaceHigh,
  disabledForegroundColor: AppBrand.muted,
  minimumSize: const Size(48, 56),
  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  textStyle: const TextStyle(fontWeight: FontWeight.w800),
);

final _outlinedButtonStyle = OutlinedButton.styleFrom(
  foregroundColor: AppBrand.text,
  minimumSize: const Size(48, 54),
  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
  side: const BorderSide(color: AppBrand.border),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  textStyle: const TextStyle(fontWeight: FontWeight.w700),
);
