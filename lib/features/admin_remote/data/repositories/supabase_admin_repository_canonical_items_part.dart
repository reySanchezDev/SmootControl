part of 'supabase_admin_repository.dart';

/// Reads the tenant-scoped master and writes only through the authorized RPC.
mixin _SupabaseAdminCanonicalItemsMixin on _SupabaseAdminRepositoryBase {
  /// Fetches the canonical master, never the legacy UNION projection.
  Future<AppResult<List<CanonicalItem>>> getCanonicalItems() => _guard(
    'canonical_items_read_failed',
    'No se pudo cargar el maestro de artículos.',
    () async {
      final rows = await _getRows('items', {
        'restaurant_id': 'eq.$_restaurantId',
        'select': 'id,code,name,item_type,base_unit_id,base_unit_cost,'
            'base_unit_price,can_sell,can_purchase,visible_in_pos,'
            'uses_recipe,send_to_kitchen,is_active',
        'order': 'name.asc',
      });
      final links = await _getRows('item_classification_links', {
        'restaurant_id': 'eq.$_restaurantId',
        'select': 'item_id,classification_id',
      });
      final byItem = <String, List<String>>{};
      for (final link in links) {
        final itemId = _text(link['item_id']);
        final classificationId = _text(link['classification_id']);
        byItem.putIfAbsent(itemId, () => []).add(classificationId);
      }
      return rows.map((row) {
        return CanonicalItem.fromRow(
          row,
          classificationIds: byItem[_text(row['id'])] ?? const [],
        );
      }).toList();
    },
  );

  /// Fetches functional labels independently of technical article types.
  Future<AppResult<List<CanonicalClassification>>>
      getCanonicalClassifications() => _guard(
    'canonical_classifications_read_failed',
    'No se pudieron cargar las clasificaciones.',
    () async {
      final rows = await _getRows('item_classifications', {
        'restaurant_id': 'eq.$_restaurantId',
        'select': 'id,code,name,is_active',
        'is_active': 'eq.true',
        'order': 'name.asc',
      });
      return rows.map((row) {
        return CanonicalClassification(
          id: _text(row['id']),
          name: _text(row['name']),
          code: _text(row['code']),
        );
      }).toList();
    },
  );

  /// Reads canonical packaging rules without the legacy packaging master.
  Future<AppResult<List<CanonicalConsumptionRule>>>
      getCanonicalConsumptionRules() => _guard(
    'canonical_rules_read_failed',
    'No se pudieron cargar las reglas de consumo.',
    () async {
      final rows = await _getRows('item_consumption_rules', {
        'restaurant_id': 'eq.$_restaurantId',
        'select': 'id,source_item_id,consumed_item_id,sales_type_id,'
            'scope,quantity,unit_id,priority,is_active',
        'order': 'priority.asc',
      });
      return rows.map(CanonicalConsumptionRule.fromRow).toList();
    },
  );

  /// Writes a rule through the transactionally revisioned V2 server RPC.
  Future<AppResult<CanonicalConsumptionRule>> saveCanonicalConsumptionRule(
    CanonicalConsumptionRule rule,
  ) => _guard(
    'canonical_rule_save_failed',
    'No se pudo guardar la regla de consumo.',
    () async {
      final row = await _rpc('app_upsert_item_consumption_rule_v2', {
        'p_restaurant_id': _restaurantId,
        'p_payload': rule.toPayload(),
      });
      if (_text(row['id']).isEmpty) {
        throw StateError('El servidor no confirmó la regla.');
      }
      return CanonicalConsumptionRule.fromRow(row);
    },
  );

  /// Creates or updates an article atomically via the trusted V2 writer.
  Future<AppResult<CanonicalItem>> saveCanonicalItem(CanonicalItem item) =>
      _guard(
        'canonical_item_save_failed',
        'No se pudo guardar el artículo.',
        () async {
          final row = await _rpc('app_upsert_item_v2', {
            'p_restaurant_id': _restaurantId,
            'p_payload': item.toPayload(),
          });
          if (_text(row['id']).isEmpty) {
            throw StateError('El servidor no confirmó el artículo.');
          }
          return CanonicalItem.fromRow(
            row,
            classificationIds: item.classificationIds,
          );
        },
      );
}
