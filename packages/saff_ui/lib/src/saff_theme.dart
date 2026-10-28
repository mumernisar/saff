import 'package:flutter/material.dart';
import 'package:saff_ui/src/tokens/saff_colors.dart';
import 'package:saff_ui/src/tokens/saff_tokens.dart';

/// Builds the app theme from the colour tokens.
abstract final class SaffTheme {
  /// Light theme.
  static ThemeData light() => _build(SaffColors.light, Brightness.light);

  /// Dark theme.
  static ThemeData dark() => _build(SaffColors.dark, Brightness.dark);

  static ThemeData _build(SaffColors c, Brightness b) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: c.accent,
          brightness: b,
        ).copyWith(
          primary: c.accent,
          onPrimary: const Color(0xFF161A22),
          surface: c.surface,
          onSurface: c.text,
          error: c.error,
          outline: c.line,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SaffRadii.md),
          side: BorderSide(color: c.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.line, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.soft,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, color: c.text),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: const Color(0xFF161A22),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaffRadii.pill),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: c.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaffRadii.pill),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaffRadii.md),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaffRadii.md),
          borderSide: BorderSide(color: c.line),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.text,
        contentTextStyle: TextStyle(color: c.bg),
      ),
    );
  }
}

/// Shortcut to the palette of the current theme.
extension SaffThemeX on BuildContext {
  /// The Saff colour tokens.
  SaffColors get saff => Theme.of(this).extension<SaffColors>()!;
}
