part of 'canonical_item_editor.dart';

/// Compact business sections arranged as a responsive form, not a list of rows.
extension _CanonicalItemEditorFields on _CanonicalItemEditorState {
  Widget _section(BuildContext context, String title, Widget content) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 20),
            content,
          ],
        ),
      );

  Widget _fields(
    BuildContext context,
    List<MeasurementUnit> units,
    List<ProductCategory> categories,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 18.0;
      final wide = constraints.maxWidth >= 680;
      final fieldWidth = wide
          ? (constraints.maxWidth - gap) / 2
          : constraints.maxWidth;
      Widget grid(List<Widget> fields) => Wrap(
        spacing: gap,
        runSpacing: 14,
        children: [
          for (final field in fields) SizedBox(width: fieldWidth, child: field),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(
            context,
            'Información general',
            grid([
              TextFormField(
                controller: _commercialCode,
                decoration: const InputDecoration(
                  labelText: 'Código comercial',
                  helperText: 'Dejá vacío para asignarlo automáticamente',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final code = int.tryParse((value ?? '').trim());
                  return value != null &&
                          value.trim().isNotEmpty &&
                          (code == null || code <= 0)
                      ? 'Ingresá un número válido'
                      : null;
                },
              ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                maxLength: 250,
                validator: _required,
              ),
              DropdownButtonFormField<CanonicalItemClass>(
                initialValue: _itemClass,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Clase de artículo *',
                ),
                items: CanonicalItemClass.values
                    .map(
                      (itemClass) => DropdownMenuItem(
                        value: itemClass,
                        child: Text(itemClass.label),
                      ),
                    )
                    .toList(),
                onChanged: (itemClass) {
                  if (itemClass == null) return;
                  _update(() {
                    _itemClass = itemClass;
                    if (itemClass == CanonicalItemClass.service) {
                      _type = CanonicalItemType.service;
                      _usesRecipe = false;
                    } else if (_type == CanonicalItemType.service) {
                      _type = CanonicalItemType.nonInventory;
                    }
                    if (itemClass == CanonicalItemClass.packaging) {
                      _canSell = false;
                      _visibleInPos = false;
                      _usesRecipe = false;
                      _sendToKitchen = false;
                    }
                  });
                },
              ),
              DropdownButtonFormField<CanonicalItemType>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo *'),
                items: CanonicalItemType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: (type) {
                  if (type == null) return;
                  _update(() {
                    _type = type;
                    if (type == CanonicalItemType.service) {
                      _usesRecipe = false;
                    }
                  });
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: units.any((unit) => unit.id == _baseUnit)
                    ? _baseUnit
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Unidad base *'),
                items: units
                    .map(
                      (unit) => DropdownMenuItem(
                        value: unit.id,
                        child: Text('${unit.name} (${unit.code})'),
                      ),
                    )
                    .toList(),
                onChanged: (id) => _update(() => _baseUnit = id),
                validator: _required,
              ),
              DropdownButtonFormField<String?>(
                initialValue:
                    categories.any(
                      (category) => category.id == _categoryId,
                    )
                    ? _categoryId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  const DropdownMenuItem<String?>(
                    child: Text('Sin categoría'),
                  ),
                  ...categories.map(
                    (category) => DropdownMenuItem<String?>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  ),
                ],
                onChanged: (id) => _update(() => _categoryId = id),
              ),
            ]),
          ),
          _section(
            context,
            'Valores comerciales',
            grid([
              TextFormField(
                controller: _cost,
                decoration: const InputDecoration(
                  labelText: 'Costo por unidad base',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _nonnegative,
              ),
              TextFormField(
                controller: _price,
                decoration: const InputDecoration(
                  labelText: 'Precio por unidad base',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _nonnegative,
              ),
            ]),
          ),
          _section(
            context,
            'Clasificaciones',
            widget.classifications.isEmpty
                ? const Text('No hay clasificaciones configuradas.')
                : Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final classification in widget.classifications)
                        FilterChip(
                          label: Text(classification.name),
                          selected: _classifications.contains(
                            classification.id,
                          ),
                          onSelected: (selected) => _update(() {
                            if (selected) {
                              _classifications.add(classification.id);
                            } else {
                              _classifications.remove(classification.id);
                            }
                          }),
                        ),
                    ],
                  ),
          ),
          _section(
            context,
            'Operación',
            grid([
              SwitchListTile(
                title: const Text('Se puede vender'),
                contentPadding: EdgeInsets.zero,
                value: _canSell,
                onChanged: (value) => _update(() {
                  _canSell = value;
                  if (!value) _visibleInPos = false;
                }),
              ),
              SwitchListTile(
                title: const Text('Se puede comprar'),
                contentPadding: EdgeInsets.zero,
                value: _canPurchase,
                onChanged: (value) => _update(() => _canPurchase = value),
              ),
              SwitchListTile(
                title: const Text('Visible en POS'),
                contentPadding: EdgeInsets.zero,
                value: _visibleInPos,
                onChanged: _canSell
                    ? (value) => _update(() => _visibleInPos = value)
                    : null,
              ),
              SwitchListTile(
                title: const Text('Utiliza receta'),
                contentPadding: EdgeInsets.zero,
                value: _usesRecipe,
                onChanged: _type == CanonicalItemType.service
                    ? null
                    : (value) => _update(() => _usesRecipe = value),
              ),
              SwitchListTile(
                title: const Text('Enviar a cocina'),
                contentPadding: EdgeInsets.zero,
                value: _sendToKitchen,
                onChanged: (value) => _update(() => _sendToKitchen = value),
              ),
              SwitchListTile(
                title: const Text('Activo'),
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: (value) => _update(() => _isActive = value),
              ),
            ]),
          ),
        ],
      );
    },
  );
}
