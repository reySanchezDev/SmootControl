part of 'staff_admin_pages.dart';

typedef _RawConsumptionDialogData = ({
  List<Employee> employees,
  List<RawMaterialProductOption> products,
  List<MeasurementUnit> units,
});

class _RawLineDraft {
  _RawLineDraft({
    required this.id,
    this.product,
    this.unitId,
    String quantity = '',
    String price = '',
  }) : quantity = TextEditingController(text: quantity),
       price = TextEditingController(text: price);

  final String id;
  RawMaterialProductOption? product;
  String? unitId;
  final TextEditingController quantity;
  final TextEditingController price;

  void dispose() {
    quantity.dispose();
    price.dispose();
  }
}

class _RawMaterialLineCard extends StatelessWidget {
  const _RawMaterialLineCard({
    required this.line,
    required this.products,
    required this.units,
    required this.onChanged,
    required this.onRemove,
    required this.defaultUnit,
  });

  final _RawLineDraft line;
  final List<RawMaterialProductOption> products;
  final List<MeasurementUnit> units;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final String? Function(RawMaterialProductOption?) defaultUnit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<RawMaterialProductOption>(
              initialValue: line.product,
              decoration: const InputDecoration(labelText: 'Materia prima'),
              items: products
                  .map(
                    (product) => DropdownMenuItem(
                      value: product,
                      child: Text(product.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                line.product = value;
                line.unitId = defaultUnit(value);
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.quantity,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: line.unitId,
                    decoration: const InputDecoration(labelText: 'Unidad'),
                    items: _unitOptions(line.product, units)
                        .map(
                          (unit) => DropdownMenuItem(
                            value: unit.id,
                            child: Text('${unit.name} (${unit.code})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      line.unitId = value;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            TextField(
              controller: line.price,
              decoration: const InputDecoration(
                labelText: 'Precio a descontar',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Quitar linea',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MeasurementUnit> _unitOptions(
    RawMaterialProductOption? product,
    List<MeasurementUnit> units,
  ) {
    final ids = <String?>{
      product?.inventoryUnitId,
      product?.purchaseUnitId,
      product?.recipeDefaultUnitId,
      product?.inventoryDisplayUnitId,
    }..remove(null);
    return units.where((unit) => ids.contains(unit.id)).toList();
  }
}
