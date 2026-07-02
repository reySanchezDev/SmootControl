import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/product_packaging_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/packaging/domain/repositories/i_packaging_repository.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/repositories/i_products_repository.dart';
import 'package:smoo_control/features/sync/domain/services/admin_data_refresh_service.dart';
import 'package:uuid/uuid.dart';

/// Manages sales types, packaging items and product packaging rules.
class PackagingPage extends StatefulWidget {
  /// Creates the page.
  const PackagingPage({super.key});

  @override
  State<PackagingPage> createState() => _PackagingPageState();
}

class _PackagingPageState extends State<PackagingPage> {
  late Future<AppResult<_PackagingSnapshot>> _future;

  IPackagingRepository get _repository =>
      serviceLocator<IPackagingRepository>();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _loadSnapshot();
  }

  Future<AppResult<_PackagingSnapshot>> _loadSnapshot() async {
    final refresh = serviceLocator<AdminDataRefreshService>();
    final productsResult = await refresh.refreshProducts();
    if (productsResult case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    final packagingResult = await refresh.refreshPackaging();
    if (packagingResult case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }

    final salesTypes = await _repository.getSalesTypes();
    final packagingItems = await _repository.getPackagingItems();
    final rules = await _repository.getRules();
    final products = await serviceLocator<IProductsRepository>().getProducts();

    if (salesTypes case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    if (packagingItems case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    if (rules case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    if (products case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }

    return AppSuccess(
      _PackagingSnapshot(
        salesTypes: (salesTypes as AppSuccess<List<SalesType>>).value,
        packagingItems:
            (packagingItems as AppSuccess<List<PackagingItem>>).value,
        rules: (rules as AppSuccess<List<ProductPackagingRule>>).value,
        products: (products as AppSuccess<List<Product>>).value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const AppText(
            'Empaques',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            variant: AppTextVariant.titleMedium,
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tipos de venta'),
              Tab(text: 'Empaques'),
              Tab(text: 'Reglas'),
            ],
          ),
        ),
        body: SafeArea(
          child: FutureBuilder<AppResult<_PackagingSnapshot>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const AppLoadingPage();
              return switch (snapshot.data!) {
                AppFailureResult(:final error) => AppEmptyState(
                  icon: Icons.error_outline,
                  title: 'Empaques',
                  message: error.message,
                ),
                AppSuccess(:final value) => TabBarView(
                  children: [
                    _SalesTypesTab(
                      salesTypes: value.salesTypes,
                      onSave: _saveSalesType,
                    ),
                    _PackagingItemsTab(
                      items: value.packagingItems,
                      onSave: _savePackagingItem,
                    ),
                    _RulesTab(
                      packagingItems: value.packagingItems,
                      products: value.products,
                      rules: value.rules,
                      salesTypes: value.salesTypes,
                      onSave: _saveRule,
                    ),
                  ],
                ),
              };
            },
          ),
        ),
      ),
    );
  }

  Future<void> _saveSalesType(SalesType? salesType) async {
    final saved = await showDialog<SalesType>(
      context: context,
      builder: (_) => _SalesTypeDialog(salesType: salesType),
    );
    if (saved == null || !mounted) return;
    await _save(
      _repository.saveSalesType(saved),
      successMessage: 'Tipo de venta guardado.',
    );
  }

  Future<void> _savePackagingItem(PackagingItem? item) async {
    final saved = await showDialog<PackagingItem>(
      context: context,
      builder: (_) => _PackagingItemDialog(item: item),
    );
    if (saved == null || !mounted) return;
    await _save(
      _repository.savePackagingItem(saved),
      successMessage: 'Empaque guardado.',
    );
  }

  Future<void> _saveRule(ProductPackagingRule? rule) async {
    final snapshot = await _future;
    if (!mounted || snapshot is! AppSuccess<_PackagingSnapshot>) return;
    final saved = await showDialog<ProductPackagingRule>(
      context: context,
      builder: (_) => _PackagingRuleDialog(
        packagingItems: snapshot.value.packagingItems,
        products: snapshot.value.products,
        rule: rule,
        salesTypes: snapshot.value.salesTypes,
      ),
    );
    if (saved == null || !mounted) return;
    await _save(
      _repository.saveRule(saved),
      successMessage: 'Regla de empaque guardada.',
    );
  }

  Future<void> _save<T>(
    Future<AppResult<T>> future, {
    required String successMessage,
  }) async {
    final result = await future;
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
        setState(_reload);
      case AppFailureResult(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
    }
  }
}

class _SalesTypesTab extends StatelessWidget {
  const _SalesTypesTab({
    required this.salesTypes,
    required this.onSave,
  });

  final List<SalesType> salesTypes;
  final ValueChanged<SalesType?> onSave;

  @override
  Widget build(BuildContext context) {
    return _CatalogList(
      emptyIcon: Icons.room_service_outlined,
      emptyMessage: 'Crea al menos Comer aqui y Para llevar.',
      emptyTitle: 'Sin tipos de venta',
      onCreate: () => onSave(null),
      children: [
        for (final type in salesTypes)
          ListTile(
            leading: Icon(
              type.isDefault ? Icons.star_outlined : Icons.room_service,
            ),
            title: AppText(type.name),
            subtitle: AppText(
              '${type.code} - Orden ${type.displayOrder} - '
              '${type.isActive ? 'Activo' : 'Inactivo'}'
              '${type.isDefault ? ' - Por defecto' : ''}',
              variant: AppTextVariant.label,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => onSave(type),
              tooltip: 'Editar',
            ),
          ),
      ],
    );
  }
}

class _PackagingItemsTab extends StatelessWidget {
  const _PackagingItemsTab({
    required this.items,
    required this.onSave,
  });

  final List<PackagingItem> items;
  final ValueChanged<PackagingItem?> onSave;

  @override
  Widget build(BuildContext context) {
    return _CatalogList(
      emptyIcon: Icons.takeout_dining_outlined,
      emptyMessage: 'Crea bandejas, bolsas, vasos u otros empaques.',
      emptyTitle: 'Sin empaques',
      onCreate: () => onSave(null),
      children: [
        for (final item in items)
          ListTile(
            leading: const Icon(Icons.takeout_dining_outlined),
            title: AppText(item.name),
            subtitle: AppText(
              '${MoneyFormatter.format(item.costInCents)} - '
              '${item.tracksStock ? 'Controla stock' : 'No controla stock'} - '
              '${item.isActive ? 'Activo' : 'Inactivo'}',
              variant: AppTextVariant.label,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => onSave(item),
              tooltip: 'Editar',
            ),
          ),
      ],
    );
  }
}

class _RulesTab extends StatelessWidget {
  const _RulesTab({
    required this.packagingItems,
    required this.products,
    required this.rules,
    required this.salesTypes,
    required this.onSave,
  });

  final List<PackagingItem> packagingItems;
  final List<Product> products;
  final List<ProductPackagingRule> rules;
  final List<SalesType> salesTypes;
  final ValueChanged<ProductPackagingRule?> onSave;

  @override
  Widget build(BuildContext context) {
    return _CatalogList(
      emptyIcon: Icons.rule_folder_outlined,
      emptyMessage:
          'Define que empaque consume cada producto por tipo de venta.',
      emptyTitle: 'Sin reglas de empaque',
      onCreate: products.isEmpty || packagingItems.isEmpty || salesTypes.isEmpty
          ? null
          : () => onSave(null),
      children: [
        for (final rule in rules)
          ListTile(
            leading: const Icon(Icons.rule_outlined),
            title: AppText(_productName(rule.productId)),
            subtitle: AppText(
              '${_salesTypeName(rule.salesTypeId)} -> '
              '${_packagingName(rule.packagingItemId)} x '
              '${rule.quantityPerUnit} por unidad - '
              '${rule.isActive ? 'Activa' : 'Inactiva'}',
              variant: AppTextVariant.label,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => onSave(rule),
              tooltip: 'Editar',
            ),
          ),
      ],
    );
  }

  String _productName(String id) {
    for (final product in products) {
      if (product.id == id) return product.name;
    }
    return 'Producto no encontrado';
  }

  String _salesTypeName(String id) {
    for (final type in salesTypes) {
      if (type.id == id) return type.name;
    }
    return 'Tipo no encontrado';
  }

  String _packagingName(String id) {
    for (final item in packagingItems) {
      if (item.id == id) return item.name;
    }
    return 'Empaque no encontrado';
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({
    required this.children,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.emptyTitle,
    required this.onCreate,
  });

  final List<Widget> children;
  final IconData emptyIcon;
  final String emptyMessage;
  final String emptyTitle;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              icon: Icons.add,
              label: 'Nuevo',
              onPressed: onCreate,
            ),
          ),
        ),
        Expanded(
          child: children.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: emptyIcon,
                    message: emptyMessage,
                    title: emptyTitle,
                  ),
                )
              : ListView.separated(
                  itemCount: children.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) => children[index],
                ),
        ),
      ],
    );
  }
}

class _SalesTypeDialog extends StatefulWidget {
  const _SalesTypeDialog({this.salesType});

  final SalesType? salesType;

  @override
  State<_SalesTypeDialog> createState() => _SalesTypeDialogState();
}

class _SalesTypeDialogState extends State<_SalesTypeDialog> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _orderController = TextEditingController();
  bool _isDefault = false;
  bool _isActive = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final type = widget.salesType;
    _nameController.text = type?.name ?? '';
    _codeController.text = type?.code ?? '';
    _orderController.text = (type?.displayOrder ?? 0).toString();
    _isDefault = type?.isDefault ?? false;
    _isActive = type?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ResponsiveDialog(
      title: widget.salesType == null ? 'Nuevo tipo de venta' : 'Tipo de venta',
      onSave: _submit,
      children: [
        AppInput(label: 'Nombre', controller: _nameController),
        const SizedBox(height: 12),
        AppInput(label: 'Codigo', controller: _codeController),
        const SizedBox(height: 12),
        AppInput(
          label: 'Orden',
          controller: _orderController,
          keyboardType: TextInputType.number,
        ),
        SwitchListTile(
          value: _isDefault,
          onChanged: (value) => setState(() => _isDefault = value),
          title: const Text('Tipo por defecto'),
        ),
        SwitchListTile(
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value),
          title: const Text('Activo'),
        ),
        if (_error != null) AppText(_error!, maxLines: 3),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final order = int.tryParse(_orderController.text.trim()) ?? 0;
    if (name.isEmpty || code.isEmpty) {
      setState(() => _error = 'Ingresa nombre y codigo.');
      return;
    }
    Navigator.of(context).pop(
      SalesType(
        id: widget.salesType?.id ?? const Uuid().v4(),
        code: code,
        name: name,
        displayOrder: order,
        isDefault: _isDefault,
        isActive: _isActive,
      ),
    );
  }
}

class _PackagingItemDialog extends StatefulWidget {
  const _PackagingItemDialog({this.item});

  final PackagingItem? item;

  @override
  State<_PackagingItemDialog> createState() => _PackagingItemDialogState();
}

class _PackagingItemDialogState extends State<_PackagingItemDialog> {
  final _nameController = TextEditingController();
  final _costController = TextEditingController();
  bool _tracksStock = true;
  bool _isActive = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController.text = item?.name ?? '';
    _costController.text = item == null
        ? ''
        : (item.costInCents / 100).toStringAsFixed(2);
    _tracksStock = item?.tracksStock ?? true;
    _isActive = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ResponsiveDialog(
      title: widget.item == null ? 'Nuevo empaque' : 'Empaque',
      onSave: _submit,
      children: [
        AppInput(label: 'Nombre', controller: _nameController),
        const SizedBox(height: 12),
        AppInput(
          label: 'Costo unitario',
          controller: _costController,
          keyboardType: TextInputType.number,
        ),
        SwitchListTile(
          value: _tracksStock,
          onChanged: (value) => setState(() => _tracksStock = value),
          title: const Text('Controla stock'),
        ),
        SwitchListTile(
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value),
          title: const Text('Activo'),
        ),
        if (_error != null) AppText(_error!, maxLines: 3),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    final cost = MoneyFormatter.parseToCents(_costController.text);
    if (name.isEmpty || cost == null || cost < 0) {
      setState(() => _error = 'Ingresa nombre y costo valido.');
      return;
    }
    Navigator.of(context).pop(
      PackagingItem(
        id: widget.item?.id ?? const Uuid().v4(),
        name: name,
        costInCents: cost,
        tracksStock: _tracksStock,
        isActive: _isActive,
      ),
    );
  }
}

class _PackagingRuleDialog extends StatefulWidget {
  const _PackagingRuleDialog({
    required this.packagingItems,
    required this.products,
    required this.salesTypes,
    this.rule,
  });

  final List<PackagingItem> packagingItems;
  final List<Product> products;
  final ProductPackagingRule? rule;
  final List<SalesType> salesTypes;

  @override
  State<_PackagingRuleDialog> createState() => _PackagingRuleDialogState();
}

class _PackagingRuleDialogState extends State<_PackagingRuleDialog> {
  final _quantityController = TextEditingController();
  String? _productId;
  String? _salesTypeId;
  String? _packagingItemId;
  bool _isActive = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _productId =
        rule?.productId ??
        (widget.products.isEmpty ? null : widget.products.first.id);
    _salesTypeId =
        rule?.salesTypeId ??
        (widget.salesTypes.isEmpty ? null : widget.salesTypes.first.id);
    _packagingItemId =
        rule?.packagingItemId ??
        (widget.packagingItems.isEmpty ? null : widget.packagingItems.first.id);
    _quantityController.text = (rule?.quantityPerUnit ?? 1).toString();
    _isActive = rule?.isActive ?? true;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ResponsiveDialog(
      title: widget.rule == null ? 'Nueva regla' : 'Regla de empaque',
      onSave: _submit,
      children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Producto'),
          initialValue: _productId,
          isExpanded: true,
          items: [
            for (final product in widget.products)
              DropdownMenuItem(value: product.id, child: Text(product.name)),
          ],
          onChanged: (value) => setState(() => _productId = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Tipo de venta'),
          initialValue: _salesTypeId,
          isExpanded: true,
          items: [
            for (final type in widget.salesTypes)
              DropdownMenuItem(value: type.id, child: Text(type.name)),
          ],
          onChanged: (value) => setState(() => _salesTypeId = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Empaque'),
          initialValue: _packagingItemId,
          isExpanded: true,
          items: [
            for (final item in widget.packagingItems)
              DropdownMenuItem(value: item.id, child: Text(item.name)),
          ],
          onChanged: (value) => setState(() => _packagingItemId = value),
        ),
        const SizedBox(height: 12),
        AppInput(
          label: 'Cantidad por unidad vendida',
          controller: _quantityController,
          keyboardType: TextInputType.number,
        ),
        SwitchListTile(
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value),
          title: const Text('Activa'),
        ),
        if (_error != null) AppText(_error!, maxLines: 3),
      ],
    );
  }

  void _submit() {
    final productId = _productId;
    final salesTypeId = _salesTypeId;
    final packagingItemId = _packagingItemId;
    final quantity = int.tryParse(_quantityController.text.trim());
    if (productId == null ||
        salesTypeId == null ||
        packagingItemId == null ||
        quantity == null ||
        quantity <= 0) {
      setState(() => _error = 'Selecciona producto, tipo, empaque y cantidad.');
      return;
    }
    Navigator.of(context).pop(
      ProductPackagingRule(
        id: widget.rule?.id ?? const Uuid().v4(),
        productId: productId,
        salesTypeId: salesTypeId,
        packagingItemId: packagingItemId,
        quantityPerUnit: quantity,
        isActive: _isActive,
      ),
    );
  }
}

class _ResponsiveDialog extends StatelessWidget {
  const _ResponsiveDialog({
    required this.children,
    required this.onSave,
    required this.title,
  });

  final List<Widget> children;
  final VoidCallback onSave;
  final String title;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      title: AppText(title, variant: AppTextVariant.titleMedium),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width < 520 ? width * 0.92 : 420),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
          primary: false,
        ),
        AppButton(label: 'Guardar', onPressed: onSave),
      ],
    );
  }
}

class _PackagingSnapshot {
  const _PackagingSnapshot({
    required this.packagingItems,
    required this.products,
    required this.rules,
    required this.salesTypes,
  });

  final List<PackagingItem> packagingItems;
  final List<Product> products;
  final List<ProductPackagingRule> rules;
  final List<SalesType> salesTypes;
}
