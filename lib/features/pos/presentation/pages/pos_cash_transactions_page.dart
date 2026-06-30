import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/payment_methods/domain/repositories/i_payment_methods_repository.dart';
import 'package:smoo_control/features/roles/domain/services/access_control_service.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:smoo_control/features/sync/domain/services/sync_scheduler_service.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Shows completed transactions for the current open cash register.
class PosCashTransactionsPage extends StatefulWidget {
  /// Creates the transactions page.
  const PosCashTransactionsPage({
    required this.cashRegisterSessionId,
    super.key,
  });

  /// Current open cash register session id.
  final String cashRegisterSessionId;

  @override
  State<PosCashTransactionsPage> createState() =>
      _PosCashTransactionsPageState();
}

class _PosCashTransactionsPageState extends State<PosCashTransactionsPage> {
  late Future<_TransactionsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPageScaffold(
      title: l10n.posViewTransactionsAction,
      body: FutureBuilder<_TransactionsData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) return const AppLoadingPage();
          final failure = data.failure;
          if (failure != null) {
            return AppEmptyState(
              icon: Icons.error_outline,
              message: failure,
              title: l10n.posViewTransactionsAction,
            );
          }
          if (data.sales.isEmpty) {
            return AppEmptyState(
              icon: Icons.receipt_long_outlined,
              message: l10n.posNoTransactionsMessage,
              title: l10n.posViewTransactionsAction,
            );
          }

          final total = data.sales.fold(
            0,
            (sum, sale) => sale.status == SaleStatus.completed
                ? sum + sale.totalInCents
                : sum,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppText(
                      l10n.posTransactionsTotalLabel,
                      variant: AppTextVariant.titleMedium,
                    ),
                    AppText(
                      MoneyFormatter.format(total),
                      variant: AppTextVariant.titleMedium,
                    ),
                    if (data.canRunManualSync)
                      AppButton(
                        icon: Icons.sync,
                        label: l10n.syncNowAction,
                        onPressed: _syncNow,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _TransactionsTable(
                  sales: data.sales,
                  paymentMethods: data.paymentMethods,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_TransactionsData> _load() async {
    final salesResult = await serviceLocator<ISalesRepository>()
        .getSalesByCashRegisterSession(widget.cashRegisterSessionId);
    final methodsResult = await serviceLocator<IPaymentMethodsRepository>()
        .getPaymentMethods();
    final canRunManualSync = await _canRunManualSync();

    return switch ((salesResult, methodsResult)) {
      (
        AppSuccess<List<Sale>>(:final value),
        AppSuccess<List<PaymentMethod>>(value: final methods),
      ) =>
        _TransactionsData(
          sales: value,
          paymentMethods: {
            for (final method in methods) method.id: method.name,
          },
          canRunManualSync: canRunManualSync,
        ),
      (AppFailureResult(:final error), _) => _TransactionsData.failure(
        error.message,
      ),
      (_, AppFailureResult(:final error)) => _TransactionsData.failure(
        error.message,
      ),
    };
  }

  Future<bool> _canRunManualSync() async {
    final session = serviceLocator<CurrentOperatorService>().session;
    if (session == null) return false;
    final result = await serviceLocator<AccessControlService>().hasPermission(
      roleId: session.roleId,
      permissionCode: 'sync.ejecutar',
    );

    return result.when(success: (value) => value, failure: (_) => false);
  }

  Future<void> _syncNow() async {
    await serviceLocator<SyncSchedulerService>().runNow();
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }
}

class _TransactionsTable extends StatelessWidget {
  const _TransactionsTable({
    required this.sales,
    required this.paymentMethods,
  });

  final List<Sale> sales;
  final Map<String, String> paymentMethods;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return ListView.separated(
            itemBuilder: (context, index) {
              final sale = sales[index];
              return _TransactionCard(
                methodName: paymentMethods[sale.paymentMethodId] ?? '',
                sale: sale,
              );
            },
            itemCount: sales.length,
            padding: const EdgeInsets.all(10),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SizedBox(
              width: constraints.maxWidth < 900 ? 900 : constraints.maxWidth,
              child: Column(
                children: [
                  _TransactionsHeader(background: colorScheme.primaryContainer),
                  Expanded(
                    child: ListView.builder(
                      itemBuilder: (context, index) {
                        final sale = sales[index];
                        return _TransactionRow(
                          methodName:
                              paymentMethods[sale.paymentMethodId] ?? '',
                          sale: sale,
                        );
                      },
                      itemCount: sales.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TransactionsHeader extends StatelessWidget {
  const _TransactionsHeader({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
        child: const Row(
          children: [
            _HeaderCell('Factura', flex: 18),
            _HeaderCell('Fecha', flex: 14),
            _HeaderCell('Hora', flex: 10),
            _HeaderCell('Metodo', flex: 18),
            _HeaderCell('Estado', flex: 18),
            _HeaderCell('Monto', flex: 14, textAlign: TextAlign.right),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.methodName,
    required this.sale,
  });

  final String methodName;
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText(
                    sale.invoiceNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    variant: AppTextVariant.titleMedium,
                  ),
                ),
                AppText(
                  MoneyFormatter.format(sale.totalInCents),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  variant: AppTextVariant.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              spacing: 12,
              children: [
                AppText(
                  '${_dateText(sale.createdAt)} ${_timeText(sale.createdAt)}',
                  variant: AppTextVariant.label,
                ),
                AppText(methodName, variant: AppTextVariant.label),
                _SyncStatusChip(status: sale.syncStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.methodName,
    required this.sale,
  });

  final String methodName;
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _BodyCell(sale.invoiceNumber, flex: 18),
          _BodyCell(_dateText(sale.createdAt), flex: 14),
          _BodyCell(_timeText(sale.createdAt), flex: 10),
          _BodyCell(methodName, flex: 18),
          Expanded(
            flex: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _SyncStatusChip(status: sale.syncStatus),
            ),
          ),
          _BodyCell(
            MoneyFormatter.format(sale.totalInCents),
            flex: 14,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

String _dateText(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _timeText(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
    this.text, {
    required this.flex,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final int flex;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(
    this.text, {
    required this.flex,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final int flex;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: AppText(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      ),
    );
  }
}

class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({required this.status});

  final SaleSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final style = switch (status) {
      SaleSyncStatus.synced => (
        icon: Icons.cloud_done_outlined,
        label: l10n.syncStatusSynced,
        color: colorScheme.primary,
      ),
      SaleSyncStatus.syncing => (
        icon: Icons.cloud_sync_outlined,
        label: l10n.syncStatusSyncing,
        color: colorScheme.tertiary,
      ),
      SaleSyncStatus.error => (
        icon: Icons.cloud_off_outlined,
        label: l10n.syncStatusError,
        color: colorScheme.error,
      ),
      SaleSyncStatus.pending => (
        icon: Icons.cloud_queue_outlined,
        label: l10n.syncStatusPending,
        color: colorScheme.onSurfaceVariant,
      ),
    };

    return Chip(
      avatar: Icon(style.icon, size: 16, color: style.color),
      label: Text(style.label),
      side: BorderSide(color: style.color),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TransactionsData {
  const _TransactionsData({
    required this.sales,
    required this.paymentMethods,
    required this.canRunManualSync,
  }) : failure = null;

  const _TransactionsData.failure(String message)
    : sales = const [],
      paymentMethods = const {},
      canRunManualSync = false,
      failure = message;

  final List<Sale> sales;
  final Map<String, String> paymentMethods;
  final bool canRunManualSync;
  final String? failure;
}
