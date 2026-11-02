import 'package:flutter/material.dart';

/// A clearly labeled action available to one administrative record.
class BackofficeRowAction {
  /// Describes an operation without hiding it behind a generic menu.
  const BackofficeRowAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  /// Visible, user-facing name of the operation.
  final String label;

  /// Icon accompanying the always-visible label.
  final IconData icon;

  /// Authorized callback; null disables the action.
  final VoidCallback? onPressed;

  /// Whether the operation requires a destructive visual treatment.
  final bool destructive;
}

/// Explicit, left-aligned operations for a Backoffice table cell.
///
/// Actions wrap onto additional lines instead of being hidden behind
/// generic overflow menus or cut off in narrow columns.
class BackofficeRowActions extends StatelessWidget {
  /// Creates a consistent action group for one row.
  const BackofficeRowActions({required this.actions, super.key});

  /// Operations already filtered according to permissions and record state.
  final List<BackofficeRowAction> actions;

  static bool _isExplicit(String label) {
    final normalized = label.trim().toLowerCase();
    return normalized.isNotEmpty &&
        !const {
          'más',
          'mas',
          'more',
          '...',
          '…',
          'opciones',
          'options',
          'acciones',
          'actions',
        }.contains(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    for (final action in actions) {
      if (!_isExplicit(action.label)) {
        throw ArgumentError.value(
          action.label,
          'label',
          'UX-040 requires a specific visible action name.',
        );
      }
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final action in actions)
            TextButton.icon(
              onPressed: action.onPressed,
              icon: Icon(action.icon, size: 17),
              label: Text(action.label, softWrap: true),
              style: TextButton.styleFrom(
                foregroundColor: action.destructive ? scheme.error : null,
                minimumSize: const Size(0, 44),
              ),
            ),
        ],
      ),
    );
  }
}
