import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/sales/data/repositories/supabase_sales_admin_repository.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'sale_detail_lines_part.dart';
part 'sale_detail_view_part.dart';
part 'sale_detail_widgets_part.dart';

/// Full administrative detail for one synchronized sale.
class SaleDetailPage extends StatefulWidget {
  /// Creates the sale detail page.
  const SaleDetailPage({required this.sale, super.key});

  /// Sale summary selected from the sales list.
  final Sale sale;

  @override
  State<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends State<SaleDetailPage> {
  late Future<_SaleDetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Detalle ${widget.sale.invoiceNumber}',
      body: FutureBuilder<_SaleDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingPage();
          }

          if (snapshot.hasError) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AppEmptyState(
                  icon: Icons.error_outline,
                  title: 'Detalle de venta',
                  message: snapshot.error.toString(),
                ),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) return const SizedBox.shrink();

          return _SaleDetailView(data: data, sale: widget.sale);
        },
      ),
    );
  }

  Future<_SaleDetailData> _load() async {
    final repository = serviceLocator<SupabaseSalesAdminRepository>();
    final paymentMethodsRepository = serviceLocator<SupabaseAdminRepository>();

    final itemsResult = await repository.getSaleItems(widget.sale.id);
    final items = switch (itemsResult) {
      AppSuccess(:final value) => value,
      AppFailureResult(:final error) => throw StateError(error.message),
    };

    final paymentNameResult = await paymentMethodsRepository
        .getPaymentMethods();
    var paymentMethodName = widget.sale.paymentMethodId;
    if (paymentNameResult case AppSuccess(:final value)) {
      for (final method in value) {
        if (method.id == widget.sale.paymentMethodId) {
          paymentMethodName = method.name;
          break;
        }
      }
    }

    return _SaleDetailData(
      items: items,
      paymentMethodName: paymentMethodName,
    );
  }
}
