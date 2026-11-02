import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_row_actions.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Administrative payment method table with explicit operations.
class PaymentMethodsBackofficeTable extends StatelessWidget {
  /// Renders an already permission-filtered list of methods.
  const PaymentMethodsBackofficeTable({
    required this.methods,
    required this.onEdit,
    required this.onDeactivate,
    required this.onRemove,
    required this.canRemove,
    required this.compactBuilder,
    super.key,
  });

  /// Displayed methods.
  final List<PaymentMethod> methods;

  /// Edit action.
  final ValueChanged<PaymentMethod> onEdit;

  /// Inactivate action.
  final ValueChanged<PaymentMethod> onDeactivate;

  /// Remove permitted levels.
  final ValueChanged<PaymentMethod> onRemove;

  /// Existing business rule for removing a level.
  final bool Function(PaymentMethod) canRemove;

  /// Preserves the mobile hierarchy UI.
  final Widget Function(BuildContext, PaymentMethod) compactBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BackofficeCollectionView<PaymentMethod>(
      items: methods,
      searchLabel: 'Buscar método de pago, grupo o moneda',
      searchTextFor: (method) => [
        method.name,
        method.groupName,
        method.currencyCode ?? '',
        if (method.isPaymentTarget) 'final',
        if (method.requiresReference) 'referencia',
        if (method.affectsCashRegister) 'efectivo',
      ].join(' '),
      emptyTitle: l10n.emptySearchTitle,
      emptyMessage: l10n.emptySearchMessage,
      compactBuilder: compactBuilder,
      columns: [
        BackofficeListColumn(
          label: 'Método de pago',
          width: 320,
          compare: (a, b) => a.name.compareTo(b.name),
          cell: (_, method) => Text(method.name, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Grupo',
          width: 200,
          compare: (a, b) => a.groupName.compareTo(b.groupName),
          cell: (_, method) => Text(method.groupName, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Moneda',
          width: 130,
          compare: (a, b) => (a.currencyCode ?? '')
              .compareTo(b.currencyCode ?? ''),
          cell: (_, method) => Text(method.currencyCode ?? '—'),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 120,
          alignment: Alignment.center,
          compare: (a, b) =>
              (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0),
          cell: (_, method) =>
              Text(method.isActive ? 'Activo' : 'Inactivo'),
        ),
        BackofficeListColumn(
          label: 'Acciones',
          width: 365,
          alignment: Alignment.center,
          cell: (_, method) => BackofficeRowActions(
            actions: [
              BackofficeRowAction(
                label: l10n.editAction,
                icon: Icons.edit_outlined,
                onPressed: () => onEdit(method),
              ),
              if (method.isActive)
                BackofficeRowAction(
                  label: l10n.deactivateAction,
                  icon: Icons.toggle_off_outlined,
                  onPressed: () => onDeactivate(method),
                ),
              if (canRemove(method))
                BackofficeRowAction(
                  label: l10n.removePaymentLevelConfirm,
                  icon: Icons.remove_circle_outline,
                  destructive: true,
                  onPressed: () => onRemove(method),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
