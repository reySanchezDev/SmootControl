part of 'canonical_items_content.dart';

extension _CanonicalItemsContentCatalog on _CanonicalItemsContentState {
  Widget _catalog(
    List<CanonicalItem> items,
    ({bool products, bool packaging}) access,
    List<ProductCategory> categories,
  ) {
    final l10n = AppLocalizations.of(context);
    final visible = items
        .where(
          (item) => item.itemClass == CanonicalItemClass.packaging
              ? access.packaging
              : access.products,
        )
        .where((item) => _classFilter == null || item.itemClass == _classFilter)
        .where((item) => _filter == null || item.type == _filter)
        .toList();
    final canCreate = _classFilter == CanonicalItemClass.packaging
        ? access.packaging
        : access.products || access.packaging;
    return Column(
      children: [
        Expanded(
          child: BackofficeCollectionView<CanonicalItem>(
            key: ValueKey(_filter?.databaseValue ?? 'all'),
            items: visible,
            rowKey: (item) => item.id ?? item.code,
            rowLabel: (item) => item.name,
            onCreate: () => _edit(null, access),
            createEnabled: !_busy && canCreate,
            globalActions: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ],
            searchTrailing: _typeFilter(),
            selectionActions: [
              BackofficeSelectionAction<CanonicalItem>(
                label: 'Editar',
                icon: Icons.edit_outlined,
                enabledWhen: (item) =>
                    !_busy &&
                    (item.itemClass == CanonicalItemClass.packaging
                        ? access.packaging
                        : access.products),
                onPressed: (item) => _edit(item, access),
              ),
              BackofficeSelectionAction<CanonicalItem>(
                label: 'Receta',
                icon: Icons.restaurant_menu_outlined,
                enabledWhen: (item) =>
                    !_busy &&
                    access.products &&
                    item.id != null &&
                    item.type != CanonicalItemType.service,
                onPressed: _recipe,
              ),
              BackofficeSelectionAction<CanonicalItem>(
                label: 'Empaques y reglas',
                icon: Icons.inventory_2_outlined,
                enabledWhen: (item) =>
                    !_busy && access.packaging && item.canSell,
                onPressed: _packagingRules,
              ),
            ],
            searchLabel: 'Buscar por código comercial o nombre',
            searchTextFor: (item) =>
                '${item.commercialCode ?? ''} ${item.name}',
            emptyTitle: items.isEmpty
                ? 'Todavía no hay artículos'
                : 'Sin coincidencias',
            emptyMessage: items.isEmpty
                ? 'Utilizá Nuevo para registrar el primer artículo.'
                : 'Revisá la búsqueda o el filtro seleccionado.',
            compactBuilder: (context, item) => ListTile(
              title: Text(item.name),
              subtitle: Text(
                '${item.commercialCode ?? '—'} · '
                '${canonicalItemTypeLabel(l10n, item.type)}',
              ),
            ),
            columns: canonicalItemColumns(categories, l10n),
          ),
        ),
      ],
    );
  }

  Widget _typeFilter() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(AppLocalizations.of(context).canonicalItemTypeField),
      const SizedBox(width: 12),
      DropdownButton<CanonicalItemType?>(
        value: _filter,
        hint: const Text('Todos'),
        items: [
          const DropdownMenuItem<CanonicalItemType?>(child: Text('Todos')),
          ...CanonicalItemType.values.map(
            (type) => DropdownMenuItem<CanonicalItemType?>(
              value: type,
              child: Text(
                canonicalItemTypeLabel(AppLocalizations.of(context), type),
              ),
            ),
          ),
        ],
        onChanged: _setTypeFilter,
      ),
    ],
  );
}
