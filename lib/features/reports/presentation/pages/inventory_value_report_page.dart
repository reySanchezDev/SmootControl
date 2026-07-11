import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_search_field.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/utils/search_text.dart';
import 'package:smoo_control/features/reports/data/services/supabase_inventory_value_report_service.dart';
import 'package:smoo_control/features/reports/domain/entities/inventory_value_report.dart';
import 'package:smoo_control/features/reports/presentation/widgets/inventory_value_report_widgets.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Current inventory value report page.
class InventoryValueReportPage extends StatefulWidget {
  /// Creates the inventory value report page.
  const InventoryValueReportPage({super.key});

  @override
  State<InventoryValueReportPage> createState() =>
      _InventoryValueReportPageState();
}

class _InventoryValueReportPageState extends State<InventoryValueReportPage> {
  final _searchController = TextEditingController();
  late Future<AppResult<InventoryValueReport>> _future;
  String _query = '';
  bool _onlyWithStock = true;

  SupabaseInventoryValueReportService get _service =>
      serviceLocator<SupabaseInventoryValueReportService>();

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
    final l10n = AppLocalizations.of(context);
    return AppPageScaffold(
      title: l10n.inventoryValueReportTitle,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InventoryFilterCard(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            onClear: _clearSearch,
            onReload: _reload,
            onStockFilterChanged: (value) {
              setState(() => _onlyWithStock = value);
            },
            onlyWithStock: _onlyWithStock,
          ),
          const SizedBox(height: 12),
          FutureBuilder<AppResult<InventoryValueReport>>(
            future: _future,
            builder: (context, snapshot) {
              final result = snapshot.data;
              if (result == null) return const AppLoadingPage();

              return result.when(
                success: (report) => _InventoryValueReportView(
                  onlyWithStock: _onlyWithStock,
                  query: _query,
                  report: report,
                ),
                failure: (failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  message: failure.message,
                  title: l10n.inventoryValueLoadErrorTitle,
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

  void _reload() {
    setState(() => _future = _service.load());
  }
}

class _InventoryFilterCard extends StatelessWidget {
  const _InventoryFilterCard({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onReload,
    required this.onStockFilterChanged,
    required this.onlyWithStock,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onReload;
  final ValueChanged<bool> onStockFilterChanged;
  final bool onlyWithStock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final search = AppSearchField(
              controller: controller,
              label: l10n.inventoryValueSearchLabel,
              onChanged: onChanged,
              onClear: onClear,
            );
            final stockSwitch = FilterChip(
              avatar: const Icon(Icons.inventory_2_outlined, size: 18),
              label: AppText(l10n.inventoryOnlyWithStockFilter),
              onSelected: onStockFilterChanged,
              selected: onlyWithStock,
            );
            final reload = FilledButton.icon(
              onPressed: onReload,
              icon: const Icon(Icons.refresh),
              label: AppText(l10n.reloadAction),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [stockSwitch]),
                  const SizedBox(height: 10),
                  reload,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 10),
                stockSwitch,
                const SizedBox(width: 10),
                reload,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InventoryValueReportView extends StatelessWidget {
  const _InventoryValueReportView({
    required this.onlyWithStock,
    required this.query,
    required this.report,
  });

  final bool onlyWithStock;
  final String query;
  final InventoryValueReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = _filteredRows;
    if (rows.isEmpty) {
      return AppEmptyState(
        icon: Icons.inventory_2_outlined,
        message: l10n.inventoryValueEmptyMessage,
        title: l10n.inventoryValueEmptyTitle,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InventoryTotalsCard(report: report),
            const SizedBox(height: 12),
            InventoryCategoryBreakdown(rows: rows),
            const SizedBox(height: 12),
            if (compact)
              InventoryMobileList(rows: rows)
            else
              InventoryDataTable(rows: rows),
          ],
        );
      },
    );
  }

  List<InventoryValueReportRow> get _filteredRows {
    return report.rows.where((row) {
      if (onlyWithStock && row.quantityOnHand <= 0) return false;
      final text = '${row.productName} ${row.categoryName}';
      return containsNormalizedSearch(text, query);
    }).toList();
  }
}
