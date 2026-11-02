import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_admin_record.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Administrative cash register listing; does not affect the POS cash view.
class CashRegisterBackofficeTable extends StatelessWidget {
  /// Builds a real remote-data cash register table.
  const CashRegisterBackofficeTable({
    required this.records,
    required this.onEdit,
    required this.onDelete,
    required this.compactBuilder,
    super.key,
  });

  /// Filtered remote register records.
  final List<CashRegisterAdminRecord> records;

  /// Existing edit flow.
  final ValueChanged<CashRegisterAdminRecord> onEdit;

  /// Existing delete flow.
  final ValueChanged<CashRegisterAdminRecord> onDelete;

  /// Preserve the current card in constrained viewports.
  final Widget Function(BuildContext, CashRegisterAdminRecord) compactBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');
    String cashier(CashRegisterAdminRecord row) =>
        row.cashierName ?? row.cashierId;

    return BackofficeCollectionView<CashRegisterAdminRecord>(
      items: records,
      searchLabel: 'Buscar cajero, fecha, estado o dispositivo',
      searchTextFor: (row) => [
        dateFormat.format(row.businessDate),
        cashier(row),
        row.deviceName ?? '',
        if (row.status == 'closed')
          l10n.cashRegisterAdminClosed
        else
          l10n.cashRegisterAdminOpened,
      ].join(' '),
      emptyTitle: l10n.emptySearchTitle,
      emptyMessage: l10n.emptySearchMessage,
      compactBuilder: compactBuilder,
      columns: [
        BackofficeListColumn(
          label: 'Fecha',
          width: 140,
          alignment: Alignment.center,
          compare: (a, b) => a.businessDate.compareTo(b.businessDate),
          cell: (_, row) => Text(dateFormat.format(row.businessDate)),
        ),
        BackofficeListColumn(
          label: 'Cajero',
          width: 225,
          compare: (a, b) => cashier(a).compareTo(cashier(b)),
          cell: (_, row) => Text(cashier(row), softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Dispositivo',
          width: 185,
          compare: (a, b) =>
              (a.deviceName ?? '').compareTo(b.deviceName ?? ''),
          cell: (_, row) => Text(row.deviceName ?? '—', softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Apertura',
          width: 155,
          alignment: Alignment.centerRight,
          compare: (a, b) =>
              a.openingCashInCents.compareTo(b.openingCashInCents),
          cell: (_, row) =>
              Text(MoneyFormatter.format(row.openingCashInCents)),
        ),
        BackofficeListColumn(
          label: 'Cierre físico',
          width: 165,
          alignment: Alignment.centerRight,
          compare: (a, b) => (a.physicalClosingCashInCents ?? 0)
              .compareTo(b.physicalClosingCashInCents ?? 0),
          cell: (_, row) => Text(
            row.physicalClosingCashInCents == null
                ? '—'
                : MoneyFormatter.format(row.physicalClosingCashInCents!),
          ),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 140,
          alignment: Alignment.center,
          compare: (a, b) => a.status.compareTo(b.status),
          cell: (_, row) => Text(
            row.status == 'closed'
                ? l10n.cashRegisterAdminClosed
                : l10n.cashRegisterAdminOpened,
          ),
        ),
        BackofficeListColumn(
          label: 'Acciones',
          width: 240,
          alignment: Alignment.center,
          cell: (_, row) => Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => onEdit(row),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: Text(l10n.editAction),
              ),
              TextButton.icon(
                onPressed: () => onDelete(row),
                icon: const Icon(Icons.delete_outline, size: 17),
                label: Text(l10n.deleteAction),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
