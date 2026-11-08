import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/product_packaging_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:uuid/uuid.dart';

/// Product-focused rule editor. Never changes the product or its identifiers.
class ProductPackagingRulesDialog extends StatefulWidget {
  /// Creates the rule editor for a persisted product.
  const ProductPackagingRulesDialog({required this.product, super.key});

  /// Existing product selected from the product catalog.
  final Product product;

  @override
  State<ProductPackagingRulesDialog> createState() =>
      _ProductPackagingRulesDialogState();
}

class _ProductPackagingRulesDialogState
    extends State<ProductPackagingRulesDialog> {
  final _repository = serviceLocator<SupabaseAdminRepository>();
  late Future<AppResult<_RuleCatalog>> _catalog = _load();

  Future<AppResult<_RuleCatalog>> _load() async {
    final rules = await _repository.getRules();
    final salesTypes = await _repository.getSalesTypes();
    final packaging = await _repository.getPackagingItems();
    if (rules case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    if (salesTypes case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    if (packaging case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    return AppSuccess(
      _RuleCatalog(
        rules: (rules as AppSuccess<List<ProductPackagingRule>>)
            .value.where((rule) => rule.productId == widget.product.id).toList(),
        salesTypes: (salesTypes as AppSuccess<List<SalesType>>).value,
        packagingItems: (packaging as AppSuccess<List<PackagingItem>>).value,
      ),
    );
  }

  Future<void> _edit(_RuleCatalog catalog, [ProductPackagingRule? original]) async {
    final changed = await showDialog<ProductPackagingRule>(
      context: context,
      builder: (_) => _ProductRuleForm(
        catalog: catalog,
        product: widget.product,
        original: original,
      ),
    );
    if (changed == null || !mounted) return;
    final result = await _repository.saveRule(changed);
    if (!mounted) return;
    await result.when(
      success: (_) async {
        setState(() => _catalog = _load());
      },
      failure: (failure) async {
        await showAppMessageDialog(
          context: context,
          title: 'No se pudo guardar la regla',
          message: failure.message,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Expanded(
                  child: Text('Empaque y consumo',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              Text(widget.product.name),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<AppResult<_RuleCatalog>>(
                  future: _catalog,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return snapshot.data!.when(
                      failure: (failure) =>
                          Center(child: Text(failure.message)),
                      success: (catalog) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: catalog.salesTypes.isEmpty ||
                                      catalog.packagingItems.isEmpty
                                  ? null
                                  : () => _edit(catalog),
                              icon: const Icon(Icons.add),
                              label: const Text('Nueva regla'),
                            ),
                          ),
                          Expanded(
                            child: catalog.rules.isEmpty
                                ? const Center(child: Text(
                                    'Este producto no tiene reglas de empaque.'))
                                : ListView.builder(
                                    itemCount: catalog.rules.length,
                                    itemBuilder: (context, index) {
                                      final rule = catalog.rules[index];
                                      final salesName = catalog.salesTypes
                                          .where((x) => x.id == rule.salesTypeId)
                                          .map((x) => x.name)
                                          .firstOrNull ?? 'Modalidad no disponible';
                                      final packagingName = catalog.packagingItems
                                          .where((x) => x.id == rule.packagingItemId)
                                          .map((x) => x.name)
                                          .firstOrNull ?? 'Empaque no disponible';
                                      return ListTile(
                                        title: Text('$salesName · $packagingName'),
                                        subtitle: Text(
                                          '${rule.quantityPerUnit} por unidad · '
                                          '${rule.isActive ? 'Activa' : 'Inactiva'}'),
                                        trailing: IconButton(
                                          tooltip: 'Editar regla',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _edit(catalog, rule),
                                        ),
                                      );
                                    }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleCatalog {
  const _RuleCatalog({
    required this.rules,
    required this.salesTypes,
    required this.packagingItems,
  });
  final List<ProductPackagingRule> rules;
  final List<SalesType> salesTypes;
  final List<PackagingItem> packagingItems;
}

class _ProductRuleForm extends StatefulWidget {
  const _ProductRuleForm({
    required this.catalog,
    required this.product,
    this.original,
  });

  final _RuleCatalog catalog;
  final Product product;
  final ProductPackagingRule? original;

  @override
  State<_ProductRuleForm> createState() => _ProductRuleFormState();
}

class _ProductRuleFormState extends State<_ProductRuleForm> {
  late String _typeId;
  late String _packagingId;
  late final TextEditingController _quantity;
  late bool _active;
  String? _error;

  @override
  void initState() {
    super.initState();
    _typeId = widget.original?.salesTypeId ??
        widget.catalog.salesTypes.first.id;
    _packagingId = widget.original?.packagingItemId ??
        widget.catalog.packagingItems.first.id;
    _quantity = TextEditingController(
      text: (widget.original?.quantityPerUnit ?? 1).toString(),
    );
    _active = widget.original?.isActive ?? true;
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _save() {
    final count = int.tryParse(_quantity.text.trim());
    if (count == null || count <= 0) {
      setState(() => _error = 'La cantidad debe ser mayor que cero.');
      return;
    }
    final duplicate = widget.catalog.rules.any((rule) =>
        rule.id != widget.original?.id &&
        rule.salesTypeId == _typeId &&
        rule.packagingItemId == _packagingId);
    if (duplicate) {
      setState(() => _error = 'Ya existe esta combinación para el producto.');
      return;
    }
    Navigator.pop(context, ProductPackagingRule(
      id: widget.original?.id ?? const Uuid().v4(),
      productId: widget.product.id,
      salesTypeId: _typeId,
      packagingItemId: _packagingId,
      quantityPerUnit: count,
      isActive: _active,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.original == null ? 'Nueva regla' : 'Editar regla'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.product.name),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _typeId,
            decoration: const InputDecoration(labelText: 'Modalidad'),
            isExpanded: true,
            items: [
              for (final type in widget.catalog.salesTypes)
                DropdownMenuItem(value: type.id, child: Text(type.name)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _typeId = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _packagingId,
            decoration: const InputDecoration(labelText: 'Empaque'),
            isExpanded: true,
            items: [
              for (final item in widget.catalog.packagingItems)
                DropdownMenuItem(value: item.id, child: Text(item.name)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _packagingId = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cantidad por unidad vendida',
            ),
          ),
          SwitchListTile(
            value: _active,
            title: const Text('Activa'),
            onChanged: (value) => setState(() => _active = value),
          ),
          if (_error != null) Text(_error!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
