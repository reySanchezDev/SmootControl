part of 'supabase_admin_repository.dart';

mixin _SupabaseAdminCatalogMixin on _SupabaseAdminRepositoryBase
    implements ICatalogRepository, IProductsRepository, IModifiersRepository {
  @override
  Future<AppResult<List<ProductCategory>>> getCategories() async {
    return _guard(
      'categories_read_failed',
      'No se pudieron leer categorias.',
      () async {
        final rows = await _getRows('product_categories', {
          'restaurant_id': 'eq.$_restaurantId',
          'select': 'id,parent_id,name,display_order,is_active',
          'order': 'display_order.asc,name.asc',
        });
        return rows.map(_categoryFromRow).toList();
      },
    );
  }

  @override
  Future<AppResult<ProductCategory>> saveCategory(
    ProductCategory category,
  ) async {
    return _guard(
      'category_save_failed',
      'No se pudo guardar categoria.',
      () async {
        await _upsert('product_categories', {
          'id': category.id,
          'restaurant_id': _restaurantId,
          'parent_id': category.parentId,
          'name': category.name,
          'display_order': category.sortOrder,
          'is_active': category.isActive,
          'updated_at': DateTime.now().toIso8601String(),
        });
        return category;
      },
    );
  }

  @override
  Future<AppResult<ProductCategory>> removeCategoryLevel(
    ProductCategory category,
  ) async {
    return _guard(
      'category_remove_failed',
      'No se pudo remover categoria.',
      () async {
        if (category.parentId == null) {
          throw StateError('No se puede eliminar una categoria raiz.');
        }
        final now = DateTime.now().toIso8601String();
        await _patchWhere(
          'product_categories',
          {'parent_id': category.parentId, 'updated_at': now},
          {'parent_id': 'eq.${category.id}'},
        );
        await _patchWhere(
          'items',
          {'category_id': category.parentId, 'updated_at': now},
          {'category_id': 'eq.${category.id}'},
        );
        await _deleteWhere('product_categories', {'id': 'eq.${category.id}'});
        return category;
      },
    );
  }

  @override
  Future<AppResult<List<Product>>> getProducts() async {
    return _guard(
      'products_read_failed',
      'No se pudieron leer productos.',
      () async {
        final products = await _getRows('items', {
          'restaurant_id': 'eq.$_restaurantId',
          'select':
              'id,category_id,name,base_unit_cost,base_unit_price,is_active,'
              'visible_in_pos,item_class,uses_recipe,tracks_inventory,'
              'purchase_unit_id,base_unit_id,purchase_to_base_factor,item_type',
          'order': 'name.asc',
        });
        final assignments = await _getRows('item_modifier_groups', {
          'restaurant_id': 'eq.$_restaurantId',
          'select': 'item_id,modifier_group_id,display_order',
          'order': 'display_order.asc',
        });
        final groupsByProduct = <String, List<String>>{};
        for (final row in assignments) {
          groupsByProduct
              .putIfAbsent(_text(row['item_id']), () => <String>[])
              .add(_text(row['modifier_group_id']));
        }
        return products.map((row) {
          final id = _text(row['id']);
          return Product(
            id: id,
            categoryId: _text(row['category_id']),
            name: _text(row['name']),
            costInCents: _moneyToCents(row['base_unit_cost']),
            priceInCents: _moneyToCents(row['base_unit_price']),
            isActive: _bool(row['is_active']),
            isAvailableInPos: _bool(
              row['visible_in_pos'],
              fallback: true,
            ),
            isRawMaterial: _text(row['item_class']) == 'raw_material',
            usesRecipe: _bool(row['uses_recipe']),
            tracksInventory: _bool(row['tracks_inventory']),
            purchaseUnitId: _nullableText(row['purchase_unit_id']),
            inventoryUnitId: _nullableText(row['base_unit_id']),
            recipeDefaultUnitId: _nullableText(row['base_unit_id']),
            inventoryDisplayUnitId: _nullableText(row['base_unit_id']),
            purchaseToInventoryFactor: row['purchase_to_base_factor'] == null
                ? null
                : _double(row['purchase_to_base_factor']),
            modifierGroupIds: groupsByProduct[id] ?? const [],
          );
        }).toList();
      },
    );
  }

  @override
  Future<AppResult<Product>> saveProduct(Product product) async {
    return _guard(
      'product_save_failed',
      'No se pudo guardar producto.',
      () async {
        await _rpc('app_upsert_item_v2', {
          'p_restaurant_id': _restaurantId,
          'p_payload': {
            'id': product.id,
            'code': product.id,
            'category_id': product.categoryId,
            'name': product.name,
            'base_unit_cost': _money(product.costInCents),
            'base_unit_price': _money(product.priceInCents),
            'is_active': product.isActive,
            'visible_in_pos': product.isAvailableInPos,
            'can_sell': !product.isRawMaterial,
            'can_purchase': product.isRawMaterial,
            'item_type': product.tracksInventory
                ? 'inventory'
                : 'non_inventory',
            'uses_recipe': product.usesRecipe,
            'send_to_kitchen': false,
          },
        });
        await _rpc('app_set_item_modifier_groups_v2', {
          'p_restaurant_id': _restaurantId,
          'p_item_id': product.id,
          'p_group_ids': product.modifierGroupIds,
        });
        return product;
      },
    );
  }

  @override
  Future<AppResult<ModifierCatalog>> getCatalog() async {
    return _guard(
      'modifiers_read_failed',
      'No se pudieron leer modificadores.',
      () async {
        final groups = await _getRows('modifier_groups', {
          'restaurant_id': 'eq.$_restaurantId',
          'select': 'id,name,is_required,display_order,is_active',
          'order': 'display_order.asc,name.asc',
        });
        final options = await _getRows('modifier_options', {
          'restaurant_id': 'eq.$_restaurantId',
          'select':
              'id,group_id,name,price_delta,display_order,is_active,'
              'is_available_in_pos',
          'order': 'display_order.asc,name.asc',
        });
        return ModifierCatalog(
          groups: groups
              .map(
                (row) => ModifierGroup(
                  id: _text(row['id']),
                  name: _text(row['name']),
                  isRequired: _bool(row['is_required'], fallback: true),
                  displayOrder: _int(row['display_order']),
                  isActive: _bool(row['is_active'], fallback: true),
                ),
              )
              .toList(),
          options: options
              .map(
                (row) => ModifierOption(
                  id: _text(row['id']),
                  groupId: _text(row['group_id']),
                  name: _text(row['name']),
                  priceDeltaInCents: _moneyToCents(row['price_delta']),
                  displayOrder: _int(row['display_order']),
                  isActive: _bool(row['is_active'], fallback: true),
                  isAvailableInPos: _bool(
                    row['is_available_in_pos'],
                    fallback: true,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  @override
  Future<AppResult<ModifierGroup>> saveGroup(ModifierGroup group) async {
    return _guard(
      'modifier_group_save_failed',
      'No se pudo guardar grupo.',
      () async {
        await _upsert('modifier_groups', {
          'id': group.id,
          'restaurant_id': _restaurantId,
          'name': group.name,
          'is_required': group.isRequired,
          'display_order': group.displayOrder,
          'is_active': group.isActive,
          'updated_at': DateTime.now().toIso8601String(),
        });
        return group;
      },
    );
  }

  @override
  Future<AppResult<ModifierOption>> saveOption(ModifierOption option) async {
    return _guard(
      'modifier_option_save_failed',
      'No se pudo guardar opcion.',
      () async {
        await _upsert('modifier_options', {
          'id': option.id,
          'restaurant_id': _restaurantId,
          'group_id': option.groupId,
          'name': option.name,
          'price_delta': _money(option.priceDeltaInCents),
          'display_order': option.displayOrder,
          'is_active': option.isActive,
          'is_available_in_pos': option.isAvailableInPos,
          'updated_at': DateTime.now().toIso8601String(),
        });
        return option;
      },
    );
  }

  @override
  Future<AppResult<ModifierOption>> saveOptionAvailability(
    ModifierOption option,
  ) {
    return saveOption(option);
  }
}
