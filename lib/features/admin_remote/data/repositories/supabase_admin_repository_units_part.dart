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
}
