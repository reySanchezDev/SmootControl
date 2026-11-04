import 'dart:async';

import 'package:flutter/material.dart';

/// Result types for explicit administrative actions.
enum BackofficeActionOutcome {
  /// The operation was confirmed as completed.
  success,

  /// The operation failed.
  error,

  /// Validation or a recoverable situation needs attention.
  warning,

  /// Neutral information for the user.
  info,
}

/// Accessible modal feedback for explicit administrative actions.
///
/// Do not show success before the persistence layer confirms it. Repeated
/// inline edits, such as daily exchange-rate cells, keep field-local feedback
/// so a modal does not interrupt keyboard entry.
abstract final class BackofficeActionFeedback {
  /// Displays a result dialog with an explicit outcome, icon, and acknowledgment.
  static void show(
    BuildContext context, {
    required BackofficeActionOutcome outcome,
    required String message,
  }) {
    final (title, icon) = switch (outcome) {
      BackofficeActionOutcome.success => (
        'Operación exitosa',
        Icons.check_circle_outline,
      ),
      BackofficeActionOutcome.error => ('Error', Icons.error_outline),
      BackofficeActionOutcome.warning => (
        'Atención',
        Icons.warning_amber_outlined,
      ),
      BackofficeActionOutcome.info => ('Información', Icons.info_outline),
    };

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final colors = Theme.of(dialogContext).colorScheme;
          final emphasis = switch (outcome) {
            BackofficeActionOutcome.success => colors.primary,
            BackofficeActionOutcome.error => colors.error,
            BackofficeActionOutcome.warning => colors.tertiary,
            BackofficeActionOutcome.info => colors.primary,
          };
          return AlertDialog(
            icon: Icon(icon, color: emphasis, size: 32),
            title: Text(title, textAlign: TextAlign.center),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(message, textAlign: TextAlign.center),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Aceptar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
