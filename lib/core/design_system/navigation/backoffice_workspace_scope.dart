import 'package:flutter/widgets.dart';

/// An asynchronous guard registered by a page before its workspace tab closes.
typedef BackofficeWorkspaceCloseGuard = Future<bool> Function();

/// Marks a page as a workspace child and exposes its close-guard registration.
class BackofficeWorkspaceScope extends InheritedWidget {
  /// Creates a stable marker for a nested page.
  const BackofficeWorkspaceScope({
    required super.child,
    this.itemId,
    this.onCloseGuardChanged,
    super.key,
  });

  /// Stable workspace tab identifier.
  final String? itemId;

  /// Receives or clears this page's asynchronous close guard.
  final void Function(String itemId, BackofficeWorkspaceCloseGuard? guard)?
  onCloseGuardChanged;

  /// Whether a context is hosted inside the Backoffice.
  static bool contains(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BackofficeWorkspaceScope>() != null;

  /// Registers the guard for the page that owns [context].
  static void registerCloseGuard(
    BuildContext context,
    BackofficeWorkspaceCloseGuard? guard,
  ) {
    final scope = context
        .getInheritedWidgetOfExactType<BackofficeWorkspaceScope>();
    final id = scope?.itemId;
    if (scope != null && id != null) scope.onCloseGuardChanged?.call(id, guard);
  }

  @override
  bool updateShouldNotify(BackofficeWorkspaceScope oldWidget) => false;
}
