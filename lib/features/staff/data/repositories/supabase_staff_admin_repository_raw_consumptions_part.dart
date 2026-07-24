part of 'supabase_staff_admin_repository.dart';

mixin _SupabaseStaffRawConsumptionsMixin on _SupabaseStaffAdminRepositoryBase {
  Future<AppResult<List<RawMaterialProductOption>>>
  getRawMaterialProductOptions() {
    return _guard(
      'raw_material_options_read_failed',
      'No se pudieron leer materias primas.',
      () async {
        final rows = await _rpcRows('app_get_raw_material_product_options', {
          'p_restaurant_id': _restaurantId,
        });
        return rows.map(_rawProductFromRow).toList();
      },
    );
  }

  Future<AppResult<List<RawMaterialStaffConsumption>>>
  getRawMaterialStaffConsumptions({
    required DateTime from,
    required DateTime to,
  }) {
    return _guard(
      'raw_material_consumptions_read_failed',
      'No se pudieron leer consumos de materia prima.',
      () async {
        final rows = await _rpcRows('app_get_raw_material_staff_consumptions', {
          'p_restaurant_id': _restaurantId,
          'p_from': _dateOnly(from),
          'p_to': _dateOnly(to),
        });
        return rows.map(_rawConsumptionFromRow).toList();
      },
    );
  }

  Future<AppResult<void>> saveRawMaterialStaffConsumption(
    RawMaterialStaffConsumption consumption,
  ) {
    return _guard(
      'raw_material_consumption_save_failed',
      'No se pudo guardar consumo de materia prima.',
      () async {
        await _rpc('app_save_raw_material_staff_consumption', {
          'p_restaurant_id': _restaurantId,
          'p_payload': {
            'id': consumption.id,
            'employee_id': consumption.employeeId,
            'consumed_at': consumption.consumedAt.toIso8601String(),
            'note': consumption.note,
            'lines': consumption.lines.map(_rawLinePayload).toList(),
          },
        });
      },
    );
  }

  Future<AppResult<void>> deleteRawMaterialStaffConsumption(
    String consumptionId,
  ) {
    return _guard(
      'raw_material_consumption_delete_failed',
      'No se pudo eliminar consumo de materia prima.',
      () async {
        await _rpc('app_delete_raw_material_staff_consumption', {
          'p_restaurant_id': _restaurantId,
          'p_consumption_id': consumptionId,
        });
      },
    );
  }

  RawMaterialProductOption _rawProductFromRow(Map<String, Object?> row) {
    return RawMaterialProductOption(
      id: _text(row['id']),
      name: _text(row['name']),
      costInCents: _moneyToCents(row['cost']),
      purchaseUnitId: _optionalText(row['purchase_unit_id']),
      inventoryUnitId: _optionalText(row['inventory_unit_id']),
      recipeDefaultUnitId: _optionalText(row['recipe_default_unit_id']),
      inventoryDisplayUnitId: _optionalText(row['inventory_display_unit_id']),
      purchaseToInventoryFactor: _doubleOrNull(
        row['purchase_to_inventory_factor'],
      ),
    );
  }

  RawMaterialStaffConsumption _rawConsumptionFromRow(
    Map<String, Object?> row,
  ) {
    return RawMaterialStaffConsumption(
      id: _text(row['id']),
      employeeId: _text(row['employee_id']),
      employeeName: _text(row['employee_name'], defaultValue: 'Empleado'),
      consumedAt:
          DateTime.tryParse(_text(row['consumed_at'])) ?? DateTime.now(),
      note: _optionalText(row['note']),
      totalInCents: _moneyToCents(row['total_amount']),
      payrollRunId: _optionalText(row['payroll_run_id']),
      lines: _rawLines(row['lines']),
    );
  }

  List<RawMaterialStaffConsumptionLine> _rawLines(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map<Object?, Object?>>().map((row) {
      final map = _map(row);
      return RawMaterialStaffConsumptionLine(
        id: _text(map['id']),
        productId: _text(map['product_id']),
        productName: _text(map['product_name']),
        quantity: _double(map['quantity']),
        inventoryQuantity: _doubleOrNull(map['inventory_quantity']),
        unitId: _optionalText(map['unit_id']),
        unitName: _optionalText(map['unit_name']),
        unitCode: _optionalText(map['unit_code']),
        unitPriceInCents: _moneyToCents(map['unit_price']),
        subtotalInCents: _moneyToCents(map['subtotal']),
      );
    }).toList();
  }

  Map<String, Object?> _rawLinePayload(
    RawMaterialStaffConsumptionLine line,
  ) {
    return {
      'id': line.id,
      'product_id': line.productId,
      'quantity': line.quantity,
      'unit_id': line.unitId,
      'unit_price': _money(line.unitPriceInCents),
    };
  }

  double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _doubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
