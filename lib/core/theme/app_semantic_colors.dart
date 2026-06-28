import 'package:flutter/material.dart';
import 'package:smoo_control/core/theme/app_palette.dart';

/// Semantic colors that are not covered by the base Material color scheme.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  /// Creates the semantic color set used by the application.
  const AppSemanticColors({
    required this.dangerAction,
    required this.onSplitAction,
    required this.splitAddAction,
    required this.splitCancelAction,
    required this.splitConfirmAction,
    required this.splitPanelForeground,
    required this.splitPanelHint,
    required this.splitSelectedItemBackground,
    required this.tableBadgeBackground,
    required this.tableOnStatus,
    required this.tableOccupiedBackground,
    required this.tableSelectedBackground,
  });

  /// Default light semantic colors used by the app and isolated widget tests.
  static const light = AppSemanticColors(
    dangerAction: AppPalette.danger,
    onSplitAction: AppPalette.textPrimary,
    splitAddAction: AppPalette.accentSoft,
    splitCancelAction: AppPalette.surfaceSecondary,
    splitConfirmAction: AppPalette.success,
    splitPanelForeground: AppPalette.textPrimary,
    splitPanelHint: AppPalette.textSecondary,
    splitSelectedItemBackground: AppPalette.surfaceSecondary,
    tableBadgeBackground: AppPalette.danger,
    tableOnStatus: AppPalette.surface,
    tableOccupiedBackground: AppPalette.accent,
    tableSelectedBackground: AppPalette.primaryDark,
  );

  /// Color for destructive catalog actions.
  final Color dangerAction;

  /// Foreground color used on split-account action buttons.
  final Color onSplitAction;

  /// Background color for adding a split account.
  final Color splitAddAction;

  /// Background color for cancelling split account editing.
  final Color splitCancelAction;

  /// Background color for confirming split account editing.
  final Color splitConfirmAction;

  /// Foreground color for split-account panels.
  final Color splitPanelForeground;

  /// Placeholder and helper text color for split-account panels.
  final Color splitPanelHint;

  /// Background color for selected split-account items.
  final Color splitSelectedItemBackground;

  /// Background color for occupied/account badges in the table band.
  final Color tableBadgeBackground;

  /// Text color for selected or occupied tables.
  final Color tableOnStatus;

  /// Background color for occupied tables.
  final Color tableOccupiedBackground;

  /// Background color for the selected table.
  final Color tableSelectedBackground;

  @override
  AppSemanticColors copyWith({
    Color? dangerAction,
    Color? onSplitAction,
    Color? splitAddAction,
    Color? splitCancelAction,
    Color? splitConfirmAction,
    Color? splitPanelForeground,
    Color? splitPanelHint,
    Color? splitSelectedItemBackground,
    Color? tableBadgeBackground,
    Color? tableOnStatus,
    Color? tableOccupiedBackground,
    Color? tableSelectedBackground,
  }) {
    return AppSemanticColors(
      dangerAction: dangerAction ?? this.dangerAction,
      onSplitAction: onSplitAction ?? this.onSplitAction,
      splitAddAction: splitAddAction ?? this.splitAddAction,
      splitCancelAction: splitCancelAction ?? this.splitCancelAction,
      splitConfirmAction: splitConfirmAction ?? this.splitConfirmAction,
      splitPanelForeground: splitPanelForeground ?? this.splitPanelForeground,
      splitPanelHint: splitPanelHint ?? this.splitPanelHint,
      splitSelectedItemBackground:
          splitSelectedItemBackground ?? this.splitSelectedItemBackground,
      tableBadgeBackground: tableBadgeBackground ?? this.tableBadgeBackground,
      tableOnStatus: tableOnStatus ?? this.tableOnStatus,
      tableOccupiedBackground:
          tableOccupiedBackground ?? this.tableOccupiedBackground,
      tableSelectedBackground:
          tableSelectedBackground ?? this.tableSelectedBackground,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      dangerAction: Color.lerp(dangerAction, other.dangerAction, t)!,
      onSplitAction: Color.lerp(onSplitAction, other.onSplitAction, t)!,
      splitAddAction: Color.lerp(splitAddAction, other.splitAddAction, t)!,
      splitCancelAction: Color.lerp(
        splitCancelAction,
        other.splitCancelAction,
        t,
      )!,
      splitConfirmAction: Color.lerp(
        splitConfirmAction,
        other.splitConfirmAction,
        t,
      )!,
      splitPanelForeground: Color.lerp(
        splitPanelForeground,
        other.splitPanelForeground,
        t,
      )!,
      splitPanelHint: Color.lerp(splitPanelHint, other.splitPanelHint, t)!,
      splitSelectedItemBackground: Color.lerp(
        splitSelectedItemBackground,
        other.splitSelectedItemBackground,
        t,
      )!,
      tableBadgeBackground: Color.lerp(
        tableBadgeBackground,
        other.tableBadgeBackground,
        t,
      )!,
      tableOnStatus: Color.lerp(tableOnStatus, other.tableOnStatus, t)!,
      tableOccupiedBackground: Color.lerp(
        tableOccupiedBackground,
        other.tableOccupiedBackground,
        t,
      )!,
      tableSelectedBackground: Color.lerp(
        tableSelectedBackground,
        other.tableSelectedBackground,
        t,
      )!,
    );
  }
}

/// Convenient access to semantic colors from widgets.
extension AppSemanticColorsContext on BuildContext {
  /// Current semantic color set.
  AppSemanticColors get semanticColors {
    return Theme.of(this).extension<AppSemanticColors>() ??
        AppSemanticColors.light;
  }
}
