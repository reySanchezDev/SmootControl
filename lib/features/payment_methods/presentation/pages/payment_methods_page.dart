import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/app_tile_actions.dart';
import 'package:smoo_control/core/design_system/backoffice_new_action.dart';
import 'package:smoo_control/core/design_system/confirm_deactivate_dialog.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/payment_methods/domain/services/payment_method_tree_service.dart';
import 'package:smoo_control/features/payment_methods/presentation/bloc/payment_methods_bloc.dart';
import 'package:smoo_control/features/payment_methods/presentation/bloc/payment_methods_event.dart';
import 'package:smoo_control/features/payment_methods/presentation/bloc/payment_methods_state.dart';
import 'package:smoo_control/features/payment_methods/presentation/widgets/create_payment_method_dialog.dart';
import 'package:smoo_control/features/payment_methods/presentation/widgets/payment_methods_backoffice_table.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'payment_method_tile.dart';

/// Payment methods management page.
class PaymentMethodsPage extends StatelessWidget {
  /// Creates the payment methods page.
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) =>
          serviceLocator<PaymentMethodsBloc>()
            ..add(const PaymentMethodsLoadRequested()),
      child: Builder(
        builder: (context) => AppPageScaffold(
          actions: [
            BackofficeNewAction(
              onPressed: () => _openCreateDialog(context),
            ),
          ],
          title: l10n.modulePaymentMethods,
          body: BlocBuilder<PaymentMethodsBloc, PaymentMethodsState>(
            builder: (context, state) {
              return switch (state) {
                PaymentMethodsInitial() ||
                PaymentMethodsLoading() => const AppLoadingPage(),
                PaymentMethodsFailure(:final failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  message: failure.message,
                  title: l10n.modulePaymentMethods,
                ),
                PaymentMethodsLoaded(:final methods) when methods.isEmpty =>
                  AppEmptyState(
                    icon: Icons.payments_outlined,
                    message: l10n.emptyPaymentMethodsMessage,
                    title: l10n.emptyPaymentMethodsTitle,
                  ),
                PaymentMethodsLoaded(:final methods) =>
                  PaymentMethodsBackofficeTable(
                    methods: _orderedMethods(methods),
                    canRemove: (method) => _canRemoveMethod(method, methods),
                    onEdit: (method) => _openEditDialog(context, method),
                    onDeactivate: (method) =>
                        _deactivateMethod(context, method),
                    onRemove: (method) =>
                        _confirmRemoveLevel(context, method),
                    compactBuilder: (context, method) => _PaymentMethodTile(
                      depth: _depthFor(method, methods),
                      method: method,
                      onDeactivate: () =>
                          _deactivateMethod(context, method),
                      onEdit: () => _openEditDialog(context, method),
                      onRemove: _canRemoveMethod(method, methods)
                          ? () => _confirmRemoveLevel(context, method)
                          : null,
                    ),
                  ),
              };
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final method = await showDialog<PaymentMethod>(
      context: context,
      builder: (_) => CreatePaymentMethodDialog(methods: _methods(context)),
    );

    if (method != null && context.mounted) {
      context.read<PaymentMethodsBloc>().add(PaymentMethodSaved(method));
    }
  }

  Future<void> _openEditDialog(
    BuildContext context,
    PaymentMethod method,
  ) async {
    final updated = await showDialog<PaymentMethod>(
      context: context,
      builder: (_) => CreatePaymentMethodDialog(
        method: method,
        methods: _methods(context),
      ),
    );

    if (updated != null && context.mounted) {
      context.read<PaymentMethodsBloc>().add(PaymentMethodSaved(updated));
    }
  }

  List<PaymentMethod> _methods(BuildContext context) {
    final state = context.read<PaymentMethodsBloc>().state;
    return switch (state) {
      PaymentMethodsLoaded(:final methods) => methods,
      _ => const [],
    };
  }

  List<PaymentMethod> _orderedMethods(List<PaymentMethod> methods) {
    final ordered = <PaymentMethod>[];
    void addBranch(String? parentId) {
      for (final method in PaymentMethodTreeService.childrenOf(
        methods,
        parentId,
      )) {
        ordered.add(method);
        addBranch(method.id);
      }
    }

    addBranch(null);
    return ordered;
  }

  int _depthFor(PaymentMethod method, List<PaymentMethod> methods) {
    var depth = 0;
    var parentId = method.parentId;
    final visited = <String>{method.id};

    while (parentId != null && visited.add(parentId)) {
      final parent = _methodById(methods, parentId);
      if (parent == null) break;
      depth++;
      parentId = parent.parentId;
    }

    return depth;
  }

  PaymentMethod? _methodById(List<PaymentMethod> methods, String id) {
    for (final method in methods) {
      if (method.id == id) return method;
    }

    return null;
  }

  bool _canRemoveMethod(PaymentMethod method, List<PaymentMethod> methods) {
    final hasChildren = methods.any((entry) => entry.parentId == method.id);
    return method.parentId != null || !hasChildren;
  }

  Future<void> _confirmRemoveLevel(
    BuildContext context,
    PaymentMethod method,
  ) async {
    final l10n = AppLocalizations.of(context);
    final isRootLeaf = method.parentId == null;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: isRootLeaf
          ? 'Eliminar método de pago'
          : l10n.removePaymentLevelTitle,
      message: isRootLeaf
          ? 'Se eliminará el método «${method.name}». '
              'Si ya tiene ventas vinculadas, la eliminación puede rechazarse.'
          : '${l10n.removePaymentLevelMessage(method.name)}\n\n'
              '${l10n.removePaymentLevelWithChildrenMessage}',
      confirmLabel: isRootLeaf
          ? l10n.deleteAction
          : l10n.removePaymentLevelConfirm,
      cancelLabel: l10n.cancelAction,
      destructive: true,
    );

    if (confirmed && context.mounted) {
      context.read<PaymentMethodsBloc>().add(PaymentMethodRemoved(method));
    }
  }

  Future<void> _deactivateMethod(
    BuildContext context,
    PaymentMethod method,
  ) async {
    final confirmed = await confirmDeactivateCatalogItem(
      context,
      name: method.name,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    context.read<PaymentMethodsBloc>().add(
      PaymentMethodSaved(
        PaymentMethod(
          id: method.id,
          name: method.name,
          parentId: method.parentId,
          groupName: method.groupName,
          currencyCode: method.currencyCode,
          displayOrder: method.displayOrder,
          isPaymentTarget: method.isPaymentTarget,
          affectsCashRegister: method.affectsCashRegister,
          requiresReference: method.requiresReference,
          isActive: false,
        ),
      ),
    );
  }
}
