import 'package:flutter/material.dart';
import 'package:smoo_control/core/theme/app_palette.dart';
import 'package:smoo_control/core/theme/app_semantic_colors.dart';

/// Application theme definitions.
abstract final class AppTheme {
  /// Light theme used by SmooControl.
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppPalette.primary,
      onPrimary: AppPalette.textPrimary,
      primaryContainer: AppPalette.surfaceSecondary,
      onPrimaryContainer: AppPalette.textPrimary,
      secondary: AppPalette.accent,
      onSecondary: AppPalette.surface,
      secondaryContainer: AppPalette.accentSoft,
      onSecondaryContainer: AppPalette.textPrimary,
      tertiary: AppPalette.success,
      onTertiary: AppPalette.surface,
      tertiaryContainer: AppPalette.surfaceSecondary,
      onTertiaryContainer: AppPalette.textPrimary,
      error: AppPalette.danger,
      onError: AppPalette.surface,
      surface: AppPalette.background,
      onSurface: AppPalette.textPrimary,
      surfaceContainerHighest: AppPalette.surfaceSecondary,
      onSurfaceVariant: AppPalette.textSecondary,
      outline: AppPalette.border,
      outlineVariant: AppPalette.border,
      inverseSurface: AppPalette.textPrimary,
      onInverseSurface: AppPalette.surface,
    );

    return ThemeData(
      colorScheme: colorScheme,
      extensions: const [AppSemanticColors.light],
      scaffoldBackgroundColor: AppPalette.background,
      useMaterial3: true,
      cardTheme: const CardThemeData(
        color: AppPalette.surface,
        surfaceTintColor: AppPalette.surface,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: AppPalette.surface,
      ),
      dividerTheme: const DividerThemeData(color: AppPalette.border),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: AppPalette.textPrimary,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppPalette.textPrimary),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppPalette.border),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppPalette.primaryDark, width: 2),
        ),
        hintStyle: TextStyle(color: AppPalette.textSecondary),
        labelStyle: TextStyle(color: AppPalette.textSecondary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.textPrimary,
          side: const BorderSide(color: AppPalette.border),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppPalette.primaryDark),
      ),
    );
  }
}
