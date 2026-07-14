part of 'supabase_catalog_pull_service.dart';

extension on SupabaseCatalogPullService {
  Future<void> _applyCategories(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'product_categories');
      remoteIds.add(id);
      await _database
          .into(_database.localProductCategories)
          .insert(
            LocalProductCategoriesCompanion(
              id: Value(id),
              parentId: Value(_optionalText(row['parent_id'])),
              name: Value(_text(row['name'], defaultValue: 'Categoria')),
              sortOrder: Value(_int(row['display_order'])),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    await _markMissingCategoriesInactive(remoteIds, now);
  }

  Future<void> _applyModifierGroups(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'modifier_groups');
      remoteIds.add(id);
      await _database
          .into(_database.localModifierGroups)
          .insert(
            LocalModifierGroupsCompanion(
              id: Value(id),
              name: Value(_text(row['name'], defaultValue: 'Grupo')),
              isRequired: Value(_bool(row['is_required'], defaultValue: true)),
              displayOrder: Value(_int(row['display_order'])),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    await _markMissingModifierGroupsInactive(remoteIds, now);
  }

  Future<void> _applyModifierOptions(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'modifier_options');
      final groupId = _optionalText(row['group_id']);
      if (groupId == null) continue;
      final local = await (_database.select(
        _database.localModifierOptions,
      )..where((option) => option.id.equals(id))).getSingleOrNull();
      remoteIds.add(id);
      await _database
          .into(_database.localModifierOptions)
          .insert(
            LocalModifierOptionsCompanion(
              id: Value(id),
              groupId: Value(groupId),
              name: Value(_text(row['name'], defaultValue: 'Opcion')),
              priceDeltaInCents: Value(_moneyCents(row['price_delta'])),
              displayOrder: Value(_int(row['display_order'])),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              isAvailableInPos: Value(
                local?.isAvailableInPos ??
                    _bool(row['is_available_in_pos'], defaultValue: true),
              ),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    await _markMissingModifierOptionsInactive(remoteIds, now);
  }

  Future<void> _applyProducts(
    List<Map<String, Object?>> rows,
    Map<String, List<String>> modifierIdsByProduct,
  ) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'products');
      final categoryId = _optionalText(row['category_id']);
      if (categoryId == null) continue;
      remoteIds.add(id);
      await _database
          .into(_database.localProducts)
          .insert(
            LocalProductsCompanion(
              id: Value(id),
              categoryId: Value(categoryId),
              name: Value(_text(row['name'], defaultValue: 'Producto')),
              priceInCents: Value(_moneyCents(row['price'])),
              costInCents: Value(_moneyCents(row['cost'])),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              isAvailableInPos: Value(
                !_bool(row['is_raw_material']) &&
                    _bool(row['is_available_in_pos'], defaultValue: true),
              ),
              isRawMaterial: Value(_bool(row['is_raw_material'])),
              tracksInventory: Value(
                _bool(row['tracks_inventory']),
              ),
              optionGroupsJson: Value(_jsonListText(row['option_groups'])),
              modifierGroupIdsJson: Value(
                StringListCodec.encode(modifierIdsByProduct[id] ?? const []),
              ),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    await _markMissingProductsInactive(remoteIds, now);
  }
}
