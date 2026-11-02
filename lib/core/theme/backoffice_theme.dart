import 'package:flutter/material.dart';
import 'package:smoo_control/core/theme/app_theme.dart';

/// Centralized Executive Ivory visual tokens for administrative screens only.
///
/// POS keeps its existing application theme.
abstract final class BackofficeDesignTokens {
  /// Accessible administrative primary (white text contrast >= 4.5:1).
  static const primary = Color(0xFF885D37);

  /// Primary text, optimized for reading dense administrative screens.
  static const ink = Color(0xFF302B27);

  /// Main workspace background.
  static const canvas = Color(0xFFF8F6F2);

  /// Surfaces used for tables and forms.
  static const surface = Color(0xFFFFFDF9);

  /// Navigation rail surface.
  static const navigation = Color(0xFFF0EAE1);

  /// Standard outlines.
  static const border = Color(0xFFE4DBD0);

  /// Standard border radius.
  static const double radius = 8;

  /// Compact action height.
  static const double controlHeight = 40;

  /// Body text size in administrative screens.
  static const double bodySize = 14;
}

/// Theme applied exclusively to the authenticated Backoffice shell.
abstract final class BackofficeTheme {
  /// Executive Ivory Material 3 theme.
  static ThemeData get executiveIvory {
    final base = AppTheme.light;
    final colors = base.colorScheme.copyWith(
      primary: BackofficeDesignTokens.primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFF0E3D1),
      secondary: BackofficeDesignTokens.primary,
      onPrimaryContainer: BackofficeDesignTokens.ink,
      surface: BackofficeDesignTokens.surface,
      surfaceContainerLow: BackofficeDesignTokens.navigation,
      onSurface: BackofficeDesignTokens.ink,
      onSurfaceVariant: const Color(0xFF60554C),
      outline: BackofficeDesignTokens.border,
      outlineVariant: BackofficeDesignTokens.border,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BackofficeDesignTokens.radius),
    );
    return base.copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: BackofficeDesignTokens.canvas,
      textTheme: base.textTheme.copyWith(
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: BackofficeDesignTokens.bodySize,
          color: BackofficeDesignTokens.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: BackofficeDesignTokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size(0, BackofficeDesignTokens.controlHeight),
          shape: shape,
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: BackofficeDesignTokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(0, BackofficeDesignTokens.controlHeight),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        indicatorColor: colors.primary,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          minimumSize: const Size(0, BackofficeDesignTokens.controlHeight),
          shape: shape,
          side: BorderSide(color: colors.outline),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: BackofficeDesignTokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BackofficeDesignTokens.radius),
          borderSide: const BorderSide(color: BackofficeDesignTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BackofficeDesignTokens.radius),
          borderSide: const BorderSide(color: BackofficeDesignTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BackofficeDesignTokens.radius),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
    );
  }
}
