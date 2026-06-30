import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_stock_item.dart';
import 'package:smoo_control/features/inventory/domain/repositories/i_inventory_repository.dart';

/// Inventory stock management page.
class InventoryPage extends StatefulWidget {
  /// Creates the page.
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late Future<AppResult<List<InventoryStockItem>>> _future;

  IInventoryRepository get _repository =>
      serviceLocator<IInventoryRepository>();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repository.getTrackedStock();
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
      body: FutureBuilder<AppResult<List<InventoryStockItem>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const AppLoadingPage();
          return switch (snapshot.data!) {
            AppFailureResult(:final error) => AppEmptyState(
              icon: Icons.error_outline,
              title: 'Inventario',
              message: error.message,
            ),
            AppSuccess(:final value) when value.isEmpty => const AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Sin productos con inventario',
              message:
                  'Activa "Controla inventario" en productos para '
                  'gestionar stock.',
            ),
            AppSuccess(:final value) => ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: value.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = value[index];
                return ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: AppText(item.productName),
                  subtitle: AppText(
                    'Actualizado: ${_formatDate(item.updatedAt)}',
                    variant: AppTextVariant.label,
                  ),
                  trailing: AppText(
                    item.quantityOnHand.toString(),
                    variant: AppTextVariant.titleMedium,
                  ),
                );
              },
            ),
          };
        },
      ),
    );
  }

  Future<void> _openPurchaseDialog() async {
    final result = await _repository.getTrackedStock();
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
      builder: (_) => _RegisterPurchaseDialog(items: items),
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

class _RegisterPurchaseDialog extends StatefulWidget {
  const _RegisterPurchaseDialog({required this.items});

  final List<InventoryStockItem> items;

  @override
  State<_RegisterPurchaseDialog> createState() =>
      _RegisterPurchaseDialogState();
}

class _RegisterPurchaseDialogState extends State<_RegisterPurchaseDialog> {
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  String? _productId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.items.isNotEmpty) {
      _productId = widget.items.first.productId;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const AppText(
        'Registrar compra',
        variant: AppTextVariant.titleMedium,
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Producto'),
                initialValue: _productId,
                isExpanded: true,
                items: [
                  for (final item in widget.items)
                    DropdownMenuItem(
                      value: item.productId,
                      child: Text(item.productName),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _productId = value),
              ),
              const SizedBox(height: 12),
              AppInput(
                label: 'Cantidad comprada',
                controller: _quantityController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppInput(
                label: 'Nota',
                controller: _notesController,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppText(_error!, maxLines: 3),
              ],
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          primary: false,
        ),
        AppButton(
          label: _saving ? 'Guardando...' : 'Guardar',
          onPressed: _saving ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final productId = _productId;
    final quantity = int.tryParse(_quantityController.text.trim());
    if (productId == null || quantity == null || quantity <= 0) {
      setState(() => _error = 'Ingresa producto y cantidad mayor que cero.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await serviceLocator<IInventoryRepository>()
        .registerPurchase(
          productId: productId,
          quantity: quantity,
          userId: serviceLocator<CurrentOperatorService>().userId,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        Navigator.of(context).pop(true);
      case AppFailureResult(:final error):
        setState(() {
          _saving = false;
          _error = error.message;
        });
    }
  }
}
