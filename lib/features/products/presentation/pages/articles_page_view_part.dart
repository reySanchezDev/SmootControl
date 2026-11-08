part of 'articles_page.dart';

extension _ArticlesPageView on _ArticlesPageState {
  Widget _articlesContent(_ArticlesSnapshot snapshot) {
    final availableTypes = <String>{
      'all',
      if (snapshot.canProducts) ...['sale', 'raw'],
      if (snapshot.canPackaging) 'packaging',
    };
    final activeType = availableTypes.contains(_type) ? _type : 'all';
    final visible = snapshot.items.where((item) {
      return switch (activeType) {
        'sale' => item.product != null && !item.product!.isRawMaterial,
        'raw' => item.product?.isRawMaterial ?? false,
        'packaging' => item.packaging != null,
        _ => true,
      };
    }).toList();
    String category(_Article item) {
      if (item.packaging != null) return 'Empaques';
      for (final c in snapshot.categories) {
        if (c.id == item.product!.categoryId) return c.name;
      }
      return 'Sin categoría';
    }

    return Column(
      children: [
        if (snapshot.warning != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Algunos artículos no están disponibles'),
              subtitle: Text(snapshot.warning!),
              trailing: IconButton(
                tooltip: 'Reintentar carga',
                icon: const Icon(Icons.refresh_outlined),
                onPressed: _reload,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Text('Tipo de artículo'),
              const SizedBox(width: 12),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 270),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(activeType),
                    initialValue: activeType,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Todos')),
                      if (snapshot.canProducts) ...[
                        const DropdownMenuItem(value: 'sale',
                            child: Text('Productos de venta')),
                        const DropdownMenuItem(value: 'raw',
                            child: Text('Materias primas')),
                      ],
                      if (snapshot.canPackaging)
                        const DropdownMenuItem(value: 'packaging',
                            child: Text('Empaques')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _type = value);
                    },
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Actualizar artículos',
                onPressed: _reload,
                icon: const Icon(Icons.refresh_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: BackofficeCollectionView<_Article>(
            key: ValueKey('articles-$activeType'),
            items: visible,
            onCreate: null,
            globalActions: [
              if (snapshot.canProducts)
                OutlinedButton.icon(
                  onPressed: () => _editProduct(null, snapshot),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo producto'),
                ),
              if (snapshot.canPackaging)
                FilledButton.icon(
                  onPressed: () => _editPackaging(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo empaque'),
                ),
            ],
            rowKey: (item) => item.id,
            rowLabel: (item) => item.name,
            selectionActions: [
              BackofficeSelectionAction<_Article>(
                label: 'Editar',
                icon: Icons.edit_outlined,
                enabledWhen: (item) => item.packaging == null
                    ? snapshot.canProducts : snapshot.canPackaging,
                onPressed: (item) {
                  if (item.product != null) {
                    _editProduct(item.product, snapshot);
                  } else {
                    _editPackaging(item.packaging);
                  }
                },
              ),
              BackofficeSelectionAction<_Article>(
                label: 'Inactivar',
                icon: Icons.toggle_off_outlined,
                enabledWhen: (item) => item.active &&
                    (item.packaging == null
                        ? snapshot.canProducts : snapshot.canPackaging),
                onPressed: _deactivate,
                destructive: true,
              ),
            ],
            searchLabel: 'Buscar por nombre, categoría, tipo o estado',
            searchTextFor: (item) =>
                '${item.name} ${item.type} ${category(item)} '
                '${MoneyFormatter.format(item.cost)} '
                '${item.active ? 'activo' : 'inactivo'}',
            emptyTitle: 'Sin artículos',
            emptyMessage: 'No hay artículos para este filtro.',
            compactBuilder: (_, item) => Card(
              child: ListTile(
                title: Text(item.name),
                subtitle: Text('${item.type} · ${category(item)} · '
                    '${item.active ? 'Activo' : 'Inactivo'}'),
              ),
            ),
            columns: [
              BackofficeListColumn<_Article>(
                label: 'Artículo',
                width: 280,
                compare: (a,b) => a.name.compareTo(b.name),
                cell: (_,item) => Text(item.name),
              ),
              BackofficeListColumn<_Article>(
                label: 'Tipo',
                width: 180,
                compare: (a,b) => a.type.compareTo(b.type),
                cell: (_,item) => Text(item.type),
              ),
              BackofficeListColumn<_Article>(
                label: 'Categoría',
                width: 200,
                compare: (a,b) => category(a).compareTo(category(b)),
                cell: (_,item) => Text(category(item)),
              ),
              BackofficeListColumn<_Article>(
                label: 'Precio venta',
                width: 130,
                alignment: Alignment.centerRight,
                cell: (_,item) => Text(item.product?.isRawMaterial == false
                    ? MoneyFormatter.format(item.product!.priceInCents)
                    : '—'),
              ),
              BackofficeListColumn<_Article>(
                label: 'Costo',
                width: 130,
                alignment: Alignment.centerRight,
                compare: (a,b) => a.cost.compareTo(b.cost),
                cell: (_,item) => Text(MoneyFormatter.format(item.cost)),
              ),
              BackofficeListColumn<_Article>(
                label: 'Inventario',
                width: 130,
                alignment: Alignment.center,
                cell: (_,item) => Text(item.stock ? 'Sí' : 'No'),
              ),
              BackofficeListColumn<_Article>(
                label: 'Estado',
                width: 130,
                alignment: Alignment.center,
                cell: (_,item) => Text(item.active ? 'Activo' : 'Inactivo'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArticlePackagingDialog extends StatefulWidget {
  const _ArticlePackagingDialog({this.item});
  final PackagingItem? item;
  @override
  State<_ArticlePackagingDialog> createState() => _ArticlePackagingDialogState();
}

class _ArticlePackagingDialogState extends State<_ArticlePackagingDialog> {
  final _name = TextEditingController();
  final _cost = TextEditingController();
  bool _stock = true;
  bool _active = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name.text = item?.name ?? '';
    _cost.text = item == null ? '' :
        (item.costInCents / 100).toStringAsFixed(2);
    _stock = item?.tracksStock ?? true;
    _active = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final cost = MoneyFormatter.parseToCents(_cost.text);
    if (name.isEmpty || cost == null || cost < 0) {
      setState(() => _error = 'Ingresá nombre y un costo válido.');
      return;
    }
    Navigator.pop(context, PackagingItem(
      id: widget.item?.id ?? const Uuid().v4(),
      name: name,
      costInCents: cost,
      tracksStock: _stock,
      isActive: _active,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'Nuevo empaque' : 'Editar empaque'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre del empaque'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Costo unitario'),
          ),
          SwitchListTile(
            value: _stock,
            onChanged: (value) => setState(() => _stock = value),
            title: const Text('Controla inventario'),
          ),
          SwitchListTile(
            value: _active,
            onChanged: (value) => setState(() => _active = value),
            title: const Text('Activo'),
          ),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _save, child: const Text('Guardar')),
    ],
  );
}
