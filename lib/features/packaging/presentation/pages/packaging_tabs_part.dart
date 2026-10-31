part of 'packaging_page.dart';

class _SalesTypesTab extends StatelessWidget {
  const _SalesTypesTab({required this.salesTypes, required this.onSave});

  final List<SalesType> salesTypes;
  final ValueChanged<SalesType?> onSave;

  @override
  Widget build(BuildContext context) {
    return _PackagingTabShell<SalesType>(
      items: salesTypes,
      searchLabel: 'Buscar tipo de venta o código',
      searchTextFor: (item) => '${item.name} ${item.code} ${item.displayOrder}',
      emptyTitle: 'Sin tipos de venta',
      emptyMessage: 'Creá los tipos de venta que utiliza el restaurante.',
      onCreate: () => onSave(null),
      compactBuilder: (_, item) => _packagingCompactItem(
        title: item.name,
        description: '${item.code} · Orden ${item.displayOrder} · '
            '${item.isActive ? 'Activo' : 'Inactivo'}'
            '${item.isDefault ? ' · Predeterminado' : ''}',
        onEdit: () => onSave(item),
      ),
      columns: [
        BackofficeListColumn(
          label: 'Tipo de venta',
          width: 290,
          compare: (a, b) => a.name.compareTo(b.name),
          cell: (_, item) => Text(item.name, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Código',
          width: 205,
          compare: (a, b) => a.code.compareTo(b.code),
          cell: (_, item) => Text(item.code, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Orden',
          width: 115,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.displayOrder.compareTo(b.displayOrder),
          cell: (_, item) => Text('${item.displayOrder}'),
        ),
        BackofficeListColumn(
          label: 'Por defecto',
          width: 145,
          alignment: Alignment.center,
          compare: (a, b) => (a.isDefault ? 1 : 0)
              .compareTo(b.isDefault ? 1 : 0),
          cell: (_, item) => Text(item.isDefault ? 'Sí' : 'No'),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 135,
          alignment: Alignment.center,
          compare: (a, b) => (a.isActive ? 1 : 0)
              .compareTo(b.isActive ? 1 : 0),
          cell: (_, item) => Text(item.isActive ? 'Activo' : 'Inactivo'),
        ),
        BackofficeListColumn(
          label: 'Acciones',
          width: 155,
          alignment: Alignment.center,
          cell: (_, item) => TextButton.icon(
            onPressed: () => onSave(item),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar'),
          ),
        ),
      ],
    );
  }
}

class _PackagingItemsTab extends StatelessWidget {
  const _PackagingItemsTab({required this.items, required this.onSave});

  final List<PackagingItem> items;
  final ValueChanged<PackagingItem?> onSave;

  @override
  Widget build(BuildContext context) {
    return _PackagingTabShell<PackagingItem>(
      items: items,
      searchLabel: 'Buscar empaque, costo o estado',
      searchTextFor: (item) => '${item.name} '
          '${MoneyFormatter.format(item.costInCents)} '
          '${item.tracksStock ? 'controla inventario' : 'sin inventario'} '
          '${item.isActive ? 'activo' : 'inactivo'}',
      emptyTitle: 'Sin empaques',
      emptyMessage: 'Registrá los empaques que utiliza el restaurante.',
      onCreate: () => onSave(null),
      compactBuilder: (_, item) => _packagingCompactItem(
        title: item.name,
        description: '${MoneyFormatter.format(item.costInCents)} · '
            '${item.tracksStock ? 'Controla inventario' : 'Sin inventario'} · '
            '${item.isActive ? 'Activo' : 'Inactivo'}',
        onEdit: () => onSave(item),
      ),
      columns: [
        BackofficeListColumn(
          label: 'Empaque',
          width: 340,
          compare: (a, b) => a.name.compareTo(b.name),
          cell: (_, item) => Text(item.name, softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Costo',
          width: 155,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.costInCents.compareTo(b.costInCents),
          cell: (_, item) => Text(MoneyFormatter.format(item.costInCents)),
        ),
        BackofficeListColumn(
          label: 'Inventario',
          width: 195,
          alignment: Alignment.center,
          compare: (a, b) => (a.tracksStock ? 1 : 0)
              .compareTo(b.tracksStock ? 1 : 0),
          cell: (_, item) => Text(item.tracksStock ? 'Sí' : 'No'),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 150,
          alignment: Alignment.center,
          compare: (a, b) => (a.isActive ? 1 : 0)
              .compareTo(b.isActive ? 1 : 0),
          cell: (_, item) => Text(item.isActive ? 'Activo' : 'Inactivo'),
        ),
        BackofficeListColumn(
          label: 'Acciones',
          width: 160,
          alignment: Alignment.center,
          cell: (_, item) => TextButton.icon(
            onPressed: () => onSave(item),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar'),
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

  String _productName(String id) {
    for (final item in products) {
      if (item.id == id) return item.name;
    }
    return 'Producto no encontrado';
  }

  String _typeName(String id) {
    for (final item in salesTypes) {
      if (item.id == id) return item.name;
    }
    return 'Tipo no encontrado';
  }

  String _packagingName(String id) {
    for (final item in packagingItems) {
      if (item.id == id) return item.name;
    }
    return 'Empaque no encontrado';
  }

  @override
  Widget build(BuildContext context) {
    return _PackagingTabShell<ProductPackagingRule>(
      items: rules,
      searchLabel: 'Buscar reglas por producto, venta o empaque',
      searchTextFor: (item) => '${_productName(item.productId)} '
          '${_typeName(item.salesTypeId)} '
          '${_packagingName(item.packagingItemId)}',
      emptyTitle: 'Sin reglas de empaque',
      emptyMessage: 'Definí qué empaque consume cada producto por tipo de venta.',
      onCreate: products.isEmpty || packagingItems.isEmpty || salesTypes.isEmpty
          ? null
          : () => onSave(null),
      compactBuilder: (_, item) => _packagingCompactItem(
        title: _productName(item.productId),
        description: '${_typeName(item.salesTypeId)} · '
            '${_packagingName(item.packagingItemId)} · '
            '${item.quantityPerUnit} por unidad · '
            '${item.isActive ? 'Activa' : 'Inactiva'}',
        onEdit: () => onSave(item),
      ),
      columns: [
        BackofficeListColumn(
          label: 'Producto',
          width: 310,
          compare: (a, b) => _productName(a.productId)
              .compareTo(_productName(b.productId)),
          cell: (_, item) => Text(_productName(item.productId), softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Tipo de venta',
          width: 260,
          compare: (a, b) => _typeName(a.salesTypeId)
              .compareTo(_typeName(b.salesTypeId)),
          cell: (_, item) => Text(_typeName(item.salesTypeId), softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Empaque',
          width: 265,
          compare: (a, b) => _packagingName(a.packagingItemId)
              .compareTo(_packagingName(b.packagingItemId)),
          cell: (_, item) =>
              Text(_packagingName(item.packagingItemId), softWrap: true),
        ),
        BackofficeListColumn(
          label: 'Cantidad',
          width: 145,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.quantityPerUnit.compareTo(b.quantityPerUnit),
          cell: (_, item) => Text('${item.quantityPerUnit}'),
        ),
        BackofficeListColumn(
          label: 'Estado',
          width: 135,
          alignment: Alignment.center,
          compare: (a, b) => (a.isActive ? 1 : 0)
              .compareTo(b.isActive ? 1 : 0),
          cell: (_, item) => Text(item.isActive ? 'Activa' : 'Inactiva'),
        ),
        BackofficeListColumn(
          label: 'Acciones',
          width: 155,
          alignment: Alignment.center,
          cell: (_, item) => TextButton.icon(
            onPressed: () => onSave(item),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar'),
          ),
        ),
      ],
    );
  }
}
