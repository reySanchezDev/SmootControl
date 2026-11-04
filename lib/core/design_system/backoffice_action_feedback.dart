import 'package:flutter/material.dart';

/// Semantic outcome of an administrative operation.
enum BackofficeActionOutcome {
  /// Persistence completed successfully.
  success,

  /// The operation failed remotely or locally.
  error,

  /// Input was rejected before persistence.
  warning,

  /// The operation reports neutral information.
  info,
}

/// Standard feedback after an administrative operation finishes.
///
/// A success must be emitted only after the persistence layer confirms it;
/// validation rejection and server failure must never be presented as success.
abstract final class BackofficeActionFeedback {
  /// Shows one accessible, nonblocking message with a visible outcome label.
  static void show(
    BuildContext context, {
    required BackofficeActionOutcome outcome,
    required String message,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final (label, icon) = switch (outcome) {
      BackofficeActionOutcome.success => (
        'Correcto',
        Icons.check_circle_outline,
      ),
      BackofficeActionOutcome.error => ('Error', Icons.error_outline),
      BackofficeActionOutcome.warning => (
        'Atención',
        Icons.warning_amber_outlined,
      ),
      BackofficeActionOutcome.info => ('Información', Icons.info_outline),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.onInverseSurface),
              const SizedBox(width: 12),
              Expanded(child: Text('$label: $message')),
            ],
          ),
        ),
      );
  }
}
