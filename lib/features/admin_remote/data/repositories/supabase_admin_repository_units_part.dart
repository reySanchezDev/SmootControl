part of 'supabase_admin_repository.dart';

mixin _SupabaseAdminUnitsMixin on _SupabaseAdminRepositoryBase {
  Future<AppResult<List<MeasurementUnit>>> getMeasurementUnits() async {
    return _guard(
      'measurement_units_read_failed',
      'No se pudieron leer unidades de medida.',
      () async {
        final rows = await _getRows('measurement_units', {
          'or': '(restaurant_id.is.null,restaurant_id.eq.$_restaurantId)',
          'select': 'id,code,name,unit_group,base_factor,is_active',
          'order': 'unit_group.asc,name.asc',
        });
        return rows.map(_unitFromRow).toList();
      },
    );
  }

  Future<AppResult<void>> createMeasurementUnit({
    required String code,
    required String name,
    required String unitGroup,
    required double baseFactor,
  }) async {
    return _guard(
      'measurement_unit_create_failed',
      'No se pudo crear la unidad de medida.',
      () => _insertUnit({
        'restaurant_id': _restaurantId,
        'code': code.trim().toLowerCase(),
        'name': name.trim(),
        'unit_group': unitGroup,
        'base_factor': baseFactor,
        'is_active': true,
      }),
    );
  }

  Future<AppResult<void>> updateMeasurementUnit(MeasurementUnit unit) async {
    return _guard(
      'measurement_unit_update_failed',
      'No se pudo guardar la unidad de medida.',
      () => _patchWhere(
        'measurement_units',
        {
          'code': unit.code.trim().toLowerCase(),
          'name': unit.name.trim(),
          'unit_group': unit.unitGroup,
          'base_factor': unit.baseFactor,
          'is_active': unit.isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        {'id': 'eq.${unit.id}', 'restaurant_id': 'eq.$_restaurantId'},
      ),
    );
  }

  Future<AppResult<void>> setMeasurementUnitActive({
    required String id,
    required bool isActive,
  }) async {
    return _guard(
      'measurement_unit_toggle_failed',
      'No se pudo cambiar el estado de la unidad de medida.',
      () => _patchWhere(
        'measurement_units',
        {
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        {'id': 'eq.$id', 'restaurant_id': 'eq.$_restaurantId'},
      ),
    );
  }

  MeasurementUnit _unitFromRow(Map<String, Object?> row) {
    return MeasurementUnit(
      id: _text(row['id']),
      code: _text(row['code']),
      name: _text(row['name']),
      unitGroup: _text(row['unit_group']),
      baseFactor: _double(row['base_factor'], fallback: 1),
      isActive: _bool(row['is_active'], fallback: true),
    );
  }

  Future<void> _insertUnit(Map<String, Object?> payload) async {
    final response = await _client.post(
      _config.restUri('measurement_units'),
      headers: _headers(prefer: 'return=minimal'),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, 'measurement_units');
  }
}
