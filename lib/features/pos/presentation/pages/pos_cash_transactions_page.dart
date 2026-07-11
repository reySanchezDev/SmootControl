import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
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
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/services/sync_scheduler_service.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'pos_cash_transactions_detail_part.dart';
part 'pos_cash_transactions_table_part.dart';
part 'pos_cash_transactions_widgets_part.dart';

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
                  canRunManualSync: data.canRunManualSync,
                  onOpenDetails: _openSaleDetail,
                  onRetry: _syncNow,
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
    final result = await serviceLocator<SyncSchedulerService>().runNow();
    if (!mounted) return;

    final message = switch (result) {
      null =>
        'Ya hay una sincronizacion en curso. Espera un momento y vuelve '
            'a revisar.',
      AppFailureResult(:final error) => error.message,
      AppSuccess(:final value) when value.failed == 0 =>
        'Sincronizacion completada. Procesadas: ${value.processed}. '
            'Correctas: ${value.succeeded}. Fallidas: 0.',
      AppSuccess(:final value) => await _syncErrorMessage(
        processed: value.processed,
        succeeded: value.succeeded,
        failed: value.failed,
      ),
    };

    setState(() {
      _future = _load();
    });

    if (!mounted) return;
    await showAppMessageDialog(
      context: context,
      message: message,
      title: 'Sincronizar ventas',
    );
  }

  Future<String> _syncErrorMessage({
    required int processed,
    required int succeeded,
    required int failed,
  }) async {
    final pendingResult = await serviceLocator<ISyncQueueRepository>()
        .getPendingItems(limit: 10);
    final lastError = pendingResult.when(
      success: (items) {
        for (final item in items) {
          final error = item.lastError;
          if (error != null && error.isNotEmpty) {
            return '${item.entityType}: $error';
          }
        }
        return null;
      },
      failure: (error) => error.message,
    );
    final detail = lastError == null
        ? ''
        : '\n\nDetalle: ${_shorten(lastError)}';
    return 'Sincronizacion con errores. Procesadas: $processed. '
        'Correctas: $succeeded. Fallidas: $failed.$detail';
  }

  String _shorten(String value) {
    const maxLength = 360;
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }

  Future<void> _openSaleDetail(Sale sale) async {
    final itemsResult = await serviceLocator<ISalesRepository>().getSaleItems(
      sale.id,
    );
    if (!mounted) return;

    switch (itemsResult) {
      case AppSuccess<List<SaleItem>>(:final value):
        await showDialog<void>(
          context: context,
          builder: (_) => _LocalSaleDetailDialog(
            canRetry: sale.syncStatus == SaleSyncStatus.error && mounted,
            items: value,
            onRetry: _retryFromDialog,
            sale: sale,
          ),
        );
      case AppFailureResult(:final error):
        await showAppMessageDialog(
          context: context,
          message: error.message,
          title: 'Detalle ${sale.invoiceNumber}',
        );
    }
  }

  Future<void> _retryFromDialog() async {
    if (mounted) {
      await Navigator.of(context, rootNavigator: true).maybePop();
    }
    await _syncNow();
  }
}
