import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_search_field.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/utils/search_text.dart';
import 'package:smoo_control/features/reports/data/services/supabase_negative_inventory_report_service.dart';
import 'package:smoo_control/features/reports/domain/entities/negative_inventory_report.dart';

part 'negative_inventory_filter_part.dart';

/// Report for raw materials below zero after recipe consumption.
class NegativeInventoryReportPage extends StatefulWidget {
  /// Creates the negative inventory report page.
  const NegativeInventoryReportPage({super.key});

  @override
  State<NegativeInventoryReportPage> createState() =>
      _NegativeInventoryReportPageState();
}

class _NegativeInventoryReportPageState
    extends State<NegativeInventoryReportPage> {
  final _searchController = TextEditingController();
  late Future<AppResult<NegativeInventoryReport>> _future;
  String _query = '';

  SupabaseNegativeInventoryReportService get _service =>
      serviceLocator<SupabaseNegativeInventoryReportService>();

  @override
  void initState() {
    super.initState();
    _future = _service.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Inventario negativo',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FilterCard(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            onClear: _clearSearch,
            onReload: _reload,
          ),
          const SizedBox(height: 12),
          FutureBuilder<AppResult<NegativeInventoryReport>>(
            future: _future,
            builder: (context, snapshot) {
              final result = snapshot.data;
              if (result == null) return const AppLoadingPage();

              return result.when(
                success: (report) => _ReportView(report: report, query: _query),
                failure: (failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  message: failure.message,
                  title: 'No se pudo cargar',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _reload() => setState(() => _future = _service.load());
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.query, required this.report});

  final String query;
  final NegativeInventoryReport report;

  @override
  Widget build(BuildContext context) {
    final rows = report.rows.where((row) {
      return containsNormalizedSearch(
        '${row.productName} ${row.categoryName}',
        query,
      );
    }).toList();

    if (rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.check_circle_outline,
        message: 'No hay materias primas negativas para este filtro.',
        title: 'Inventario saludable',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(report: report),
        const SizedBox(height: 12),
        for (final row in rows) _NegativeInventoryCard(row: row),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});

  final NegativeInventoryReport report;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer.withValues(alpha: 0.28),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    '${report.productCount} materias primas negativas',
                    variant: AppTextVariant.titleMedium,
                  ),
                  AppText(
                    'Costo estimado para regularizar: '
                    '${MoneyFormatter.format(
                      report.regularizationCostInCents,
                    )}',
                    variant: AppTextVariant.label,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NegativeInventoryCard extends StatelessWidget {
  const _NegativeInventoryCard({required this.row});

  final NegativeInventoryRow row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(row.productName, variant: AppTextVariant.titleMedium),
            const SizedBox(height: 2),
            AppText(row.categoryName, variant: AppTextVariant.label),
            const SizedBox(height: 8),
            _AmountRow(label: 'Stock actual', value: row.quantityOnHand),
            _AmountRow(
              label: 'Cantidad a regularizar',
              value: row.quantityToRegularize,
            ),
            _MoneyRow(
              label: 'Costo estimado',
              value: row.regularizationCostInCents,
            ),
            if (row.lastMovementAt != null) ...[
              const SizedBox(height: 6),
              AppText(
                'Ultimo consumo: ${_formatDateTime(row.lastMovementAt!)}',
                variant: AppTextVariant.label,
              ),
            ],
            if (row.shortReferenceId != null)
              AppText(
                'Referencia: ${row.shortReferenceId}',
                variant: AppTextVariant.label,
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) =>
      '${_two(date.day)}/${_two(date.month)}/${date.year} '
      '${_two(date.hour)}:${_two(date.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return _TextRow(label: label, value: _quantityText(value));
  }
}

String _quantityText(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(2);

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) =>
      _TextRow(label: label, value: MoneyFormatter.format(value));
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: AppText(label)),
          AppText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
            variant: AppTextVariant.label,
          ),
        ],
      ),
    );
  }
}
