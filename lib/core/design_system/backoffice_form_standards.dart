import 'package:flutter/material.dart';

/// Shared spacing and maximum control widths for the Backoffice.
abstract final class BackofficeFormStandards {
  /// Space between consecutive inputs in forms and dialogs.
  static const double fieldGap = 12;

  /// Space between independent filter groups.
  static const double filterGap = 12;

  /// Standard width for compact administrative edit dialogs.
  static const double dialogWidth = 520;

  /// Standard width for detailed administrative forms.
  static const double wideDialogWidth = 680;

  /// Space between distinct form sections.
  static const double sectionGap = 16;

  /// Maximum width of a search field on desktop.
  static const double searchWidth = 440;

  /// Maximum width of one date picker or filter.
  static const double dateWidth = 210;

  /// Maximum width of selector fields in a toolbar.
  static const double filterWidth = 260;

  /// Constrains control width on desktop without harming mobile.
  static Widget control({
    required Widget child,
    required double maxWidth,
  }) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: child,
  );
}
