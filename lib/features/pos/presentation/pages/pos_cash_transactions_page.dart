import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/payment_methods/domain/repositories/i_payment_methods_repository.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Shows completed transactions for the current open cash register.
class PosCashTransactionsPage extends StatelessWidget {
  /// Creates the transactions page.
  const PosCashTransactionsPage({
    required this.cashRegisterSessionId,
    super.key,
  });

  /// Current open cash register session id.
  final String cashRegisterSessionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPageScaffold(
      title: l10n.posViewTransactionsAction,
      body: FutureBuilder<_TransactionsData>(
        future: _load(),
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
                child: Row(
                  children: [
                    AppText(
                      l10n.posTransactionsTotalLabel,
                      variant: AppTextVariant.titleMedium,
                    ),
                    const Spacer(),
                    AppText(
                      MoneyFormatter.format(total),
                      variant: AppTextVariant.titleMedium,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemBuilder: (context, index) {
                    final sale = data.sales[index];
                    final method = data.paymentMethods[sale.paymentMethodId];
                    return ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: AppText('${sale.invoiceNumber} · ${method ?? ''}'),
                      subtitle: AppText(_timeText(sale.createdAt)),
                      trailing: AppText(
                        MoneyFormatter.format(sale.totalInCents),
                      ),
                    );
                  },
                  itemCount: data.sales.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
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
        .getSalesByCashRegisterSession(cashRegisterSessionId);
    final methodsResult = await serviceLocator<IPaymentMethodsRepository>()
        .getPaymentMethods();

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
        ),
      (AppFailureResult(:final error), _) => _TransactionsData.failure(
        error.message,
      ),
      (_, AppFailureResult(:final error)) => _TransactionsData.failure(
        error.message,
      ),
    };
  }

  String _timeText(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _TransactionsData {
  const _TransactionsData({
    required this.sales,
    required this.paymentMethods,
  }) : failure = null;

  const _TransactionsData.failure(String message)
    : sales = const [],
      paymentMethods = const {},
      failure = message;

  final List<Sale> sales;
  final Map<String, String> paymentMethods;
  final String? failure;
}
