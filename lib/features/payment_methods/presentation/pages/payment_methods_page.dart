import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_searchable_list_section.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/confirm_deactivate_dialog.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/payment_methods/domain/services/payment_method_tree_service.dart';
import 'package:smoo_control/features/payment_methods/presentation/bloc/payment_methods_bloc.dart';
import 'package:smoo_control/features/payment_methods/presentation/bloc/payment_methods_event.dart';
import 'package:smoo_control/features/payment_methods/presentation/bloc/payment_methods_state.dart';
import 'package:smoo_control/features/payment_methods/presentation/widgets/create_payment_method_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

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
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openCreateDialog(context),
              tooltip: l10n.createAction,
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
                  AppSearchableListSection<PaymentMethod>(
                    emptyMessage: l10n.emptySearchMessage,
                    emptyTitle: l10n.emptySearchTitle,
                    items: _orderedMethods(methods),
                    searchLabel: l10n.searchField,
                    searchTextForItem: _searchText,
                    itemBuilder: (context, method) => _PaymentMethodTile(
                      depth: _depthFor(method, methods),
                      method: method,
                      onDeactivate: () => _deactivateMethod(context, method),
                      onEdit: () => _openEditDialog(context, method),
                      onRemove: method.parentId == null
                          ? null
                          : () => _confirmRemoveLevel(context, method),
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

  String _searchText(PaymentMethod method) {
    return [
      method.name,
      method.groupName,
      method.currencyCode ?? '',
      if (method.isPaymentTarget) 'final',
      if (method.requiresReference) 'referencia',
      if (method.affectsCashRegister) 'efectivo',
    ].join(' ');
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

  Future<void> _confirmRemoveLevel(
    BuildContext context,
    PaymentMethod method,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.removePaymentLevelTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.removePaymentLevelMessage(method.name)),
            const SizedBox(height: 12),
            Text(l10n.removePaymentLevelWithChildrenMessage),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.removePaymentLevelConfirm),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && context.mounted) {
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

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.depth,
    required this.method,
    required this.onDeactivate,
    required this.onEdit,
    required this.onRemove,
  });

  final int depth;
  final PaymentMethod method;
  final VoidCallback onDeactivate;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final details = [
      if (method.isPaymentTarget)
        l10n.paymentFinalOptionField
      else
        l10n.paymentNavigationNode,
      if (method.currencyCode != null) method.currencyCode!,
      if (method.isActive) l10n.activeStatus else l10n.inactiveStatus,
      if (method.affectsCashRegister) l10n.cashAffectsRegister,
      if (method.requiresReference) l10n.requiresReference,
    ].join(' - ');

    return ListTile(
      contentPadding: EdgeInsets.only(left: 16 + (depth * 24), right: 16),
      leading: Icon(
        method.isPaymentTarget ? Icons.payments_outlined : Icons.folder_open,
      ),
      subtitle: AppText(details, variant: AppTextVariant.label),
      title: AppText(method.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onRemove != null)
            IconButton(
              color: Theme.of(context).colorScheme.error,
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
              tooltip: l10n.removeAction,
            ),
          if (method.isActive)
            IconButton(
              color: Theme.of(context).colorScheme.error,
              icon: const Icon(Icons.visibility_off_outlined),
              onPressed: onDeactivate,
              tooltip: l10n.deactivateAction,
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
            tooltip: l10n.editAction,
          ),
        ],
      ),
    );
  }
}
