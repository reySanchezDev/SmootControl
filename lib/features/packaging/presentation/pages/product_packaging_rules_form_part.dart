part of 'product_packaging_rules_dialog.dart';

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
    _typeId =
        widget.original?.salesTypeId ?? widget.catalog.salesTypes.first.id;
    _packagingId =
        widget.original?.packagingItemId ??
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
    final duplicate = widget.catalog.rules.any(
      (rule) =>
          rule.id != widget.original?.id &&
          rule.salesTypeId == _typeId &&
          rule.packagingItemId == _packagingId,
    );
    if (duplicate) {
      setState(() => _error = 'Ya existe esta combinación para el producto.');
      return;
    }
    Navigator.pop(
      context,
      ProductPackagingRule(
        id: widget.original?.id ?? const Uuid().v4(),
        productId: widget.product.id,
        salesTypeId: _typeId,
        packagingItemId: _packagingId,
        quantityPerUnit: count,
        isActive: _active,
      ),
    );
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
