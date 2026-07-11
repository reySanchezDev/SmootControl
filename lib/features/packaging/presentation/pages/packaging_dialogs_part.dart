part of 'packaging_page.dart';

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
