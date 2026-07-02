import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/payment_methods/domain/repositories/i_payment_methods_repository.dart';
import 'package:smoo_control/features/sales/data/repositories/supabase_sales_admin_repository.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

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
    final paymentMethodsRepository =
        serviceLocator<IPaymentMethodsRepository>();

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

class _SaleDetailView extends StatelessWidget {
  const _SaleDetailView({required this.data, required this.sale});

  final _SaleDetailData data;
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return ListView(
          padding: EdgeInsets.all(compact ? 12 : 20),
          children: [
            _HeaderSection(
              sale: sale,
              paymentMethodName: data.paymentMethodName,
            ),
            const SizedBox(height: 14),
            _LinesSection(items: data.items),
            const SizedBox(height: 14),
            _TotalsSection(sale: sale, items: data.items),
          ],
        );
      },
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.paymentMethodName,
    required this.sale,
  });

  final String paymentMethodName;
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = switch (sale.status) {
      SaleStatus.completed => l10n.saleStatusCompleted,
      SaleStatus.voided => l10n.saleStatusVoided,
    };

    return _SectionSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 820 ? 4 : 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(sale.invoiceNumber, variant: AppTextVariant.titleMedium),
              const SizedBox(height: 12),
              _InfoGrid(
                columns: columns,
                entries: [
                  _InfoEntry('Estado', status),
                  _InfoEntry('Fecha', _formatDate(sale.createdAt)),
                  _InfoEntry('Hora', _formatTime(sale.createdAt)),
                  _InfoEntry(
                    'Tipo de venta',
                    sale.salesTypeName ?? 'No definido',
                  ),
                  _InfoEntry('Metodo de pago', paymentMethodName),
                  if (sale.paymentReference != null)
                    _InfoEntry('Referencia', sale.paymentReference!),
                  if (sale.tableId != null) _InfoEntry('Mesa', sale.tableId!),
                  if (sale.cashRegisterSessionId != null)
                    _InfoEntry('Caja', sale.cashRegisterSessionId!),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LinesSection extends StatelessWidget {
  const _LinesSection({required this.items});

  final List<SaleItem> items;

  @override
  Widget build(BuildContext context) {
    return _SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Lineas', variant: AppTextVariant.titleMedium),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const AppText('Esta venta no tiene lineas registradas.')
          else
            _SaleLinesTable(items: items),
        ],
      ),
    );
  }
}

class _SaleLinesTable extends StatelessWidget {
  const _SaleLinesTable({required this.items});

  final List<SaleItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              for (final item in items) _CompactLineTile(item: item),
            ],
          );
        }

        return Table(
          columnWidths: const {
            0: FlexColumnWidth(4),
            1: FlexColumnWidth(1.1),
            2: FlexColumnWidth(1.4),
            3: FlexColumnWidth(1.4),
          },
          border: TableBorder(
            horizontalInside: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
          children: [
            _lineRow(
              context,
              isHeader: true,
              cells: const ['Producto', 'Cant.', 'Precio', 'Monto'],
            ),
            for (final item in items)
              _lineRow(
                context,
                cells: [
                  _productLabel(item),
                  item.quantity.toString(),
                  MoneyFormatter.format(item.unitPriceInCents),
                  MoneyFormatter.format(item.totalInCents),
                ],
              ),
          ],
        );
      },
    );
  }

  TableRow _lineRow(
    BuildContext context, {
    required List<String> cells,
    bool isHeader = false,
  }) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
    );
    return TableRow(
      children: [
        for (var index = 0; index < cells.length; index += 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Text(
              cells[index],
              maxLines: index == 0 ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: index == 0 ? TextAlign.start : TextAlign.end,
              style: style,
            ),
          ),
      ],
    );
  }

  String _productLabel(SaleItem item) {
    final options = item.selectedOptionsLabel?.trim();
    if (options == null || options.isEmpty) return item.productName;
    return '${item.productName}\n$options';
  }
}

class _CompactLineTile extends StatelessWidget {
  const _CompactLineTile({required this.item});

  final SaleItem item;

  @override
  Widget build(BuildContext context) {
    final options = item.selectedOptionsLabel?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(item.productName),
                if (options != null && options.isNotEmpty)
                  AppText(options, variant: AppTextVariant.label),
                AppText(
                  '${item.quantity} x '
                  '${MoneyFormatter.format(item.unitPriceInCents)}',
                  variant: AppTextVariant.label,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppText(MoneyFormatter.format(item.totalInCents)),
        ],
      ),
    );
  }
}

class _TotalsSection extends StatelessWidget {
  const _TotalsSection({required this.items, required this.sale});

  final List<SaleItem> items;
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final units = items.fold(0, (total, item) => total + item.quantity);
    return _SectionSurface(
      child: Column(
        children: [
          _TotalRow(label: 'Unidades', value: units.toString()),
          _TotalRow(
            label: 'Subtotal',
            value: MoneyFormatter.format(sale.subtotalInCents),
          ),
          _TotalRow(
            label: 'Total',
            value: MoneyFormatter.format(sale.totalInCents),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final bool emphasized;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.columns, required this.entries});

  final int columns;
  final List<_InfoEntry> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            for (final entry in entries)
              SizedBox(
                width: _itemWidth(constraints.maxWidth, columns),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(entry.label, variant: AppTextVariant.label),
                    const SizedBox(height: 2),
                    Text(
                      entry.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  double _itemWidth(double maxWidth, int columns) {
    final availableWidth = maxWidth - ((columns - 1) * 14);
    return (availableWidth / columns).clamp(150, 360).toDouble();
  }
}

class _InfoEntry {
  const _InfoEntry(this.label, this.value);

  final String label;
  final String value;
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _SaleDetailData {
  const _SaleDetailData({
    required this.items,
    required this.paymentMethodName,
  });

  final List<SaleItem> items;
  final String paymentMethodName;
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
