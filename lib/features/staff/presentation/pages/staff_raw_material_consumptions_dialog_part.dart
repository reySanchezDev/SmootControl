part of 'staff_admin_pages.dart';

class _RawMaterialConsumptionDialog extends StatefulWidget {
  const _RawMaterialConsumptionDialog({this.consumption});

  final RawMaterialStaffConsumption? consumption;

  @override
  State<_RawMaterialConsumptionDialog> createState() =>
      _RawMaterialConsumptionDialogState();
}

class _RawMaterialConsumptionDialogState
    extends State<_RawMaterialConsumptionDialog> {
  final _note = TextEditingController();
  final _uuid = const Uuid();
  DateTime _date = DateTime.now();
  String? _employeeId;
  String? _error;
  bool _saving = false;
  late Future<_RawConsumptionDialogData> _future;
  final _lines = <_RawLineDraft>[];

  SupabaseStaffAdminRepository get _staff =>
      serviceLocator<SupabaseStaffAdminRepository>();
  SupabaseAdminRepository get _admin =>
      serviceLocator<SupabaseAdminRepository>();

  @override
  void initState() {
    super.initState();
    final item = widget.consumption;
    _employeeId = item?.employeeId;
    _date = item?.consumedAt ?? DateTime.now();
    _note.text = item?.note ?? '';
    _future = _load();
  }

  @override
  void dispose() {
    _note.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.consumption == null
            ? 'Nuevo consumo de materia prima'
            : 'Editar consumo de materia prima',
      ),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<_RawConsumptionDialogData>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const AppLoadingPage();
            final data = snapshot.requireData;
            _ensureEditLines(data.products);
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _employeeId,
                    decoration: const InputDecoration(
                      labelText: 'Empleado',
                    ),
                    items: data.employees
                        .where((employee) => employee.isActive)
                        .map(
                          (employee) => DropdownMenuItem(
                            value: employee.id,
                            child: Text(employee.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _employeeId = value),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text('Fecha ${_dateOnly(_date)}'),
                    onPressed: _pickDate,
                  ),
                  TextField(
                    controller: _note,
                    decoration: const InputDecoration(labelText: 'Nota'),
                  ),
                  const SizedBox(height: 12),
                  for (final line in _lines)
                    _RawMaterialLineCard(
                      line: line,
                      products: data.products,
                      units: data.units,
                      onChanged: () => setState(() {}),
                      onRemove: () => setState(() {
                        line.dispose();
                        _lines.remove(line);
                      }),
                      defaultUnit: _defaultUnit,
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar materia prima'),
                      onPressed: () => setState(_addLine),
                    ),
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.save_outlined),
          onPressed: _saving ? null : _save,
          label: const Text('Guardar'),
        ),
      ],
    );
  }

  Future<_RawConsumptionDialogData> _load() async {
    final employees = await _staff.getEmployees();
    final products = await _staff.getRawMaterialProductOptions();
    final units = await _admin.getMeasurementUnits();
    return (
      employees: _value(employees),
      products: _value(products),
      units: _value(units),
    );
  }

  List<T> _value<T>(AppResult<List<T>> result) {
    return switch (result) {
      AppSuccess(:final value) => value,
      AppFailureResult(:final error) => throw StateError(error.message),
    };
  }

  void _ensureEditLines(List<RawMaterialProductOption> products) {
    if (_lines.isNotEmpty) return;
    final item = widget.consumption;
    if (item == null) {
      _addLine();
      return;
    }
    for (final source in item.lines) {
      final product = products.where((item) => item.id == source.productId);
      _lines.add(
        _RawLineDraft(
          id: source.id,
          product: product.isEmpty ? null : product.first,
          unitId: source.unitId,
          quantity: _decimal(source.quantity),
          price: (source.unitPriceInCents / 100).toStringAsFixed(2),
        ),
      );
    }
  }

  void _addLine() {
    _lines.add(_RawLineDraft(id: _uuid.v4()));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
    });
  }

  Future<void> _save() async {
    final employeeId = _employeeId;
    if (employeeId == null) {
      setState(() => _error = 'Selecciona el empleado.');
      return;
    }
    final lines = <RawMaterialStaffConsumptionLine>[];
    for (final draft in _lines) {
      final product = draft.product;
      final quantity = _parseNumber(draft.quantity.text);
      final price = _parseNumber(draft.price.text);
      if (product == null || draft.unitId == null) {
        setState(() => _error = 'Completa materia prima y unidad.');
        return;
      }
      if (quantity == null || quantity <= 0 || price == null || price < 0) {
        setState(() => _error = 'Verifica cantidades y precios.');
        return;
      }
      lines.add(
        RawMaterialStaffConsumptionLine(
          id: draft.id,
          productId: product.id,
          productName: product.name,
          quantity: quantity,
          unitId: draft.unitId,
          unitPriceInCents: (price * 100).round(),
          subtotalInCents: (quantity * price * 100).round(),
        ),
      );
    }
    if (lines.isEmpty) {
      setState(() => _error = 'Agrega al menos una materia prima.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await _staff.saveRawMaterialStaffConsumption(
      RawMaterialStaffConsumption(
        id: widget.consumption?.id ?? _uuid.v4(),
        employeeId: employeeId,
        employeeName: '',
        consumedAt: _date,
        note: _optional(_note.text),
        totalInCents: lines.fold(
          0,
          (total, line) => total + line.subtotalInCents,
        ),
        lines: lines,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case AppSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consumo guardado.')),
        );
        Navigator.of(context).pop(true);
      case AppFailureResult(:final error):
        setState(() => _error = error.message);
    }
  }

  String? _defaultUnit(RawMaterialProductOption? product) {
    return product?.inventoryDisplayUnitId ??
        product?.recipeDefaultUnitId ??
        product?.inventoryUnitId ??
        product?.purchaseUnitId;
  }

  double? _parseNumber(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  String _decimal(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }
}
