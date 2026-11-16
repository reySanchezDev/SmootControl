part of 'canonical_item_dialog.dart';

/// Business fields reused by the existing article editor, not a new screen.
extension _CanonicalItemEditorFields on _CanonicalItemEditorState {
  Widget _fields(BuildContext context, List<MeasurementUnit> units) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Identificación',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      TextFormField(
        controller: _code,
        decoration: const InputDecoration(
          labelText: 'Código *',
        ),
        maxLength: 64,
        validator: _required,
      ),
      TextFormField(
        controller: _name,
        decoration: const InputDecoration(
          labelText: 'Nombre *',
        ),
        maxLength: 250,
        validator: _required,
      ),
      DropdownButtonFormField<CanonicalItemType>(
        initialValue: _type,
        decoration: const InputDecoration(
          labelText: 'Tipo de artículo *',
          helperText: 'Define si el artículo controla existencias.',
        ),
        items: CanonicalItemType.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(type.label),
          );
        }).toList(),
        onChanged: (type) {
          if (type == null) return;
          setState(() {
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
        decoration: const InputDecoration(
          labelText: 'Unidad base *',
          helperText: 'Referencia para costos, precios y cantidades.',
        ),
        items: units.map((unit) {
          return DropdownMenuItem(
            value: unit.id,
            child: Text('${unit.name} (${unit.code})'),
          );
        }).toList(),
        onChanged: (id) => setState(() => _baseUnit = id),
        validator: _required,
      ),
      const Divider(),
      Text(
        'Valores comerciales',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _cost,
              decoration: const InputDecoration(
                labelText: 'Costo por unidad base',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _nonnegative,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _price,
              decoration: const InputDecoration(
                labelText: 'Precio por unidad base',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _nonnegative,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Divider(),
      Text(
        'Clasificaciones funcionales',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (widget.classifications.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Podrás asignar clasificaciones cuando estén configuradas.',
          ),
        ),
      ...widget.classifications.map((classification) {
        return CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(classification.name),
          value: _classifications.contains(classification.id),
          onChanged: (checked) {
            setState(() {
              if (checked ?? false) {
                _classifications.add(classification.id);
              } else {
                _classifications.remove(classification.id);
              }
            });
          },
        );
      }),
      const Divider(),
      Text(
        'Venta y operación',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      SwitchListTile(
        title: const Text('Se puede vender'),
        value: _canSell,
        onChanged: (value) {
          setState(() {
            _canSell = value;
            if (!value) _visibleInPos = false;
          });
        },
      ),
      SwitchListTile(
        title: const Text('Se puede comprar'),
        value: _canPurchase,
        onChanged: (value) => setState(() => _canPurchase = value),
      ),
      SwitchListTile(
        title: const Text('Visible en POS'),
        subtitle: const Text(
          'Disponible para los cajeros al vender.',
        ),
        value: _visibleInPos,
        onChanged: _canSell
            ? (value) => setState(() => _visibleInPos = value)
            : null,
      ),
      SwitchListTile(
        title: const Text('Utiliza receta'),
        subtitle: const Text(
          'Consume ingredientes según la receta configurada.',
        ),
        value: _usesRecipe,
        onChanged: _type == CanonicalItemType.service
            ? null
            : (value) => setState(() => _usesRecipe = value),
      ),
      SwitchListTile(
        title: const Text('Enviar a cocina'),
        value: _sendToKitchen,
        onChanged: (value) => setState(() => _sendToKitchen = value),
      ),
      const Divider(),
      Text('Estado', style: Theme.of(context).textTheme.titleMedium),
      SwitchListTile(
        title: const Text('Activo'),
        value: _isActive,
        onChanged: (value) => setState(() => _isActive = value),
      ),

    ],
  );
}
