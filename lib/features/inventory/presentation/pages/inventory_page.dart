import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/inventory/data/services/supabase_inventory_admin_read_service.dart';
import 'package:smoo_control/features/inventory/data/services/supabase_inventory_admin_write_service.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_stock_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_stock_item.dart';

part 'inventory_batch_packaging_dialog_part.dart';
part 'inventory_batch_product_dialog_part.dart';
part 'inventory_batch_rows_part.dart';
part 'inventory_batch_widgets_part.dart';
part 'inventory_stock_tabs_part.dart';

/// Inventory stock management page.
class InventoryPage extends StatefulWidget {
  /// Creates the page.
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<AppResult<List<InventoryStockItem>>> _productFuture;
  late Future<AppResult<List<PackagingStockItem>>> _packagingFuture;

  SupabaseInventoryAdminReadService get _remoteReadService =>
      serviceLocator<SupabaseInventoryAdminReadService>();
  SupabaseInventoryAdminWriteService get _remoteWriteService =>
      serviceLocator<SupabaseInventoryAdminWriteService>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reload() {
    _productFuture = _remoteReadService.getTrackedProductStock();
    _packagingFuture = _remoteReadService.getPackagingStock();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      actions: [
        IconButton(
          icon: const Icon(Icons.add_shopping_cart_outlined),
          onPressed: _openPurchaseDialog,
          tooltip: 'Registrar compra',
        ),
      ],
      title: 'Inventario',
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Productos'),
              Tab(text: 'Empaques'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ProductStockTab(
                  future: _productFuture,
                  formatDate: _formatDate,
                ),
                _PackagingStockTab(
                  future: _packagingFuture,
                  formatDate: _formatDate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPurchaseDialog() async {
    if (_tabController.index == 1) {
      await _openPackagingPurchaseDialog();
      return;
    }

    final result = await _remoteReadService.getTrackedProductStock();
    if (!mounted) return;
    final items = switch (result) {
      AppSuccess(:final value) => value,
      AppFailureResult() => <InventoryStockItem>[],
    };
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay productos que controlen inventario.'),
        ),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _BatchProductPurchaseDialog(
        items: items,
        writeService: _remoteWriteService,
      ),
    );
    if ((saved ?? false) && mounted) {
      setState(_reload);
    }
  }

  Future<void> _openPackagingPurchaseDialog() async {
    final result = await _remoteReadService.getPackagingStock();
    if (!mounted) return;
    final items = switch (result) {
      AppSuccess(:final value) => value,
      AppFailureResult() => <PackagingStockItem>[],
    };
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay empaques activos.')),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _BatchPackagingPurchaseDialog(
        items: items,
        writeService: _remoteWriteService,
      ),
    );
    if ((saved ?? false) && mounted) {
      setState(_reload);
    }
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }
}
