import 'package:flutter/material.dart';

/// Official SmooControl color palette.
abstract final class AppPalette {
  /// General application background.
  static const background = Color(0xFFF8F4EE);

  /// Cards, dialogs, panels, and list surfaces.
  static const surface = Color(0xFFFFFDF9);

  /// Secondary background used to separate sections.
  static const surfaceSecondary = Color(0xFFEFE7DA);

  /// Main readable text color.
  static const textPrimary = Color(0xFF2B2622);

  /// Secondary text, labels, hints, and descriptions.
  static const textSecondary = Color(0xFF7A7168);

  /// Primary action, selected, and active state color.
  static const primary = Color(0xFFC9A46A);

  /// Strong primary variant for extra contrast.
  static const primaryDark = Color(0xFFA8824A);

  /// Elegant accent used sparingly.
  static const accent = Color(0xFFB76E5D);

  /// Soft premium accent used sparingly.
  static const accentSoft = Color(0xFFD8B7A6);

  /// Borders, dividers, and input lines.
  static const border = Color(0xFFDDD2C4);

  /// Error and destructive action color.
  static const danger = Color(0xFF9A3D4A);

  /// Success and confirmation color.
  static const success = Color(0xFF7C8B6B);

  /// Soft premium green for available POS tables.
  static const tableAvailableSoft = Color(0xFFDDE8D6);

  /// Elegant wine red for occupied POS tables.
  static const tableOccupiedWine = Color(0xFF7F2E3B);
}
