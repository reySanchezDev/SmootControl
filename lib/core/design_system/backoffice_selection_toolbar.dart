import 'package:flutter/material.dart';

/// Command on the selected Backoffice record, not a per-row action.
class BackofficeSelectionAction<T> {
  /// Names the operation explicitly, even when no row is selected.
  const BackofficeSelectionAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabledWhen,
    this.labelFor,
    this.destructive = false,
  });

  /// Visible label when no record is selected.
  final String label;

  /// Optional state-specific label, e.g. Activar or Inactivar.
  final String Function(T item)? labelFor;

  /// Icon beside the visible label.
  final IconData icon;

  /// Existing authorized operation.
  final ValueChanged<T> onPressed;

  /// Business rule deciding whether the selected record supports the action.
  final bool Function(T item)? enabledWhen;

  /// Distinguishes destructive operations.
  final bool destructive;
}

/// Fixed toolbar: actions never move, disappear or hide behind a More menu.
class BackofficeSelectionToolbar<T> extends StatelessWidget {
  /// Builds a toolbar for one selected record.
  const BackofficeSelectionToolbar({
    required this.actions,
    required this.selected,
    this.selectedLabel,
    this.onCreate,
    super.key,
  });

  /// All operations in stable order.
  final List<BackofficeSelectionAction<T>> actions;

  /// Current row or null when nothing is selected.
  final T? selected;

  /// Human-readable name of the selected record.
  final String? selectedLabel;

  /// Available regardless of row selection, subject to permissions.
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (onCreate != null)
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nuevo'),
                ),
              for (final action in actions)
                OutlinedButton.icon(
                  onPressed: selected != null &&
                          (action.enabledWhen?.call(selected as T) ?? true)
                      ? () => action.onPressed(selected as T)
                      : null,
                  icon: Icon(action.icon, size: 18),
                  label: Text(
                    selected == null
                        ? action.label
                        : action.labelFor?.call(selected as T) ?? action.label,
                    softWrap: true,
                  ),
                  style: action.destructive
                      ? OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                        )
                      : null,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              selected == null
                  ? 'Seleccioná un registro para habilitar las acciones.'
                  : 'Seleccionado: ${selectedLabel ?? 'Registro'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
