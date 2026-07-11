part of 'packaging_page.dart';

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
            title: AppText(
              type.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: AppText(
              '${type.code} - Orden ${type.displayOrder} - '
              '${type.isActive ? 'Activo' : 'Inactivo'}'
              '${type.isDefault ? ' - Por defecto' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
            title: AppText(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: AppText(
              '${MoneyFormatter.format(item.costInCents)} - '
              '${item.tracksStock ? 'Controla stock' : 'No controla stock'} - '
              '${item.isActive ? 'Activo' : 'Inactivo'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
            title: AppText(
              _productName(rule.productId),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: AppText(
              '${_salesTypeName(rule.salesTypeId)} -> '
              '${_packagingName(rule.packagingItemId)} x '
              '${rule.quantityPerUnit} por unidad - '
              '${rule.isActive ? 'Activa' : 'Inactiva'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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
