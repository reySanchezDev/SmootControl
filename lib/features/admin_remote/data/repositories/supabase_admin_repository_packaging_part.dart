part of 'supabase_admin_repository.dart';

mixin _SupabaseAdminPackagingMixin on _SupabaseAdminRepositoryBase
    implements IPackagingRepository {
  @override
  Future<AppResult<List<SalesType>>> getSalesTypes() async {
    return _guard(
      'sales_types_read_failed',
      'No se pudieron leer tipos de venta.',
      () async {
        final rows = await _getRows('sales_types', {
          'restaurant_id': 'eq.$_restaurantId',
          'select': '*',
          'order': 'display_order.asc,name.asc',
        });
        return rows.map(_salesTypeFromRow).toList();
      },
    );
  }

  @override
  Future<AppResult<SalesType>> saveSalesType(SalesType salesType) async {
    return _guard(
      'sales_type_save_failed',
      'No se pudo guardar tipo de venta.',
      () async {
        await _upsert('sales_types', {
          'id': salesType.id,
          'restaurant_id': _restaurantId,
          'code': salesType.code,
          'name': salesType.name,
          'display_order': salesType.displayOrder,
          'is_default': salesType.isDefault,
          'is_active': salesType.isActive,
          'updated_at': DateTime.now().toIso8601String(),
        });
        return salesType;
      },
    );
  }

  @override
  Future<AppResult<List<PackagingItem>>> getPackagingItems() async {
    return _guard(
      'packaging_items_read_failed',
      'No se pudieron leer empaques.',
      () async {
        final rows = await _getRows('packaging_items', {
          'restaurant_id': 'eq.$_restaurantId',
          'select': 'id,name,cost,tracks_stock,is_active',
          'order': 'name.asc',
        });
        return rows
            .map(
              (row) => PackagingItem(
                id: _text(row['id']),
                name: _text(row['name']),
                costInCents: _moneyToCents(row['cost']),
                tracksStock: _bool(row['tracks_stock'], fallback: true),
                isActive: _bool(row['is_active'], fallback: true),
              ),
            )
            .toList();
      },
    );
  }

  @override
  Future<AppResult<PackagingItem>> savePackagingItem(
    PackagingItem item,
  ) async {
    return _guard(
      'packaging_item_save_failed',
      'No se pudo guardar empaque.',
      () async {
        await _upsert('packaging_items', {
          'id': item.id,
          'restaurant_id': _restaurantId,
          'name': item.name,
          'cost': _money(item.costInCents),
          'tracks_stock': item.tracksStock,
          'is_active': item.isActive,
          'updated_at': DateTime.now().toIso8601String(),
        });
        return item;
      },
    );
  }

  @override
  Future<AppResult<List<ProductPackagingRule>>> getRules() async {
    return _guard(
      'packaging_rules_read_failed',
      'No se pudieron leer reglas de empaque.',
      () async {
        final rows = await _getRows('product_packaging_rules', {
          'restaurant_id': 'eq.$_restaurantId',
          'select':
              'id,product_id,sales_type_id,packaging_item_id,'
              'quantity_per_unit,is_active',
        });
        return rows.map(_packagingRuleFromRow).toList();
      },
    );
  }

  @override
  Future<AppResult<ProductPackagingRule>> saveRule(
    ProductPackagingRule rule,
  ) async {
    return _guard(
      'packaging_rule_save_failed',
      'No se pudo guardar regla de empaque.',
      () async {
        await _upsert('product_packaging_rules', {
          'id': rule.id,
          'restaurant_id': _restaurantId,
          'product_id': rule.productId,
          'sales_type_id': rule.salesTypeId,
          'packaging_item_id': rule.packagingItemId,
          'quantity_per_unit': rule.quantityPerUnit,
          'is_active': rule.isActive,
          'updated_at': DateTime.now().toIso8601String(),
        });
        return rule;
      },
    );
  }

  @override
  Future<AppResult<List<PackagingStockItem>>> getPackagingStock() async {
    return _guard(
      'packaging_stock_read_failed',
      'No se pudo leer stock de empaques.',
      () async {
        final items = await getPackagingItems();
        final packagingItems = switch (items) {
          AppSuccess(:final value) => value,
          AppFailureResult(:final error) => throw StateError(error.message),
        };
        final stockRows = await _getRows('packaging_stock', {
          'restaurant_id': 'eq.$_restaurantId',
          'select': 'packaging_item_id,quantity_on_hand,updated_at',
        });
        final stockById = {
          for (final row in stockRows) _text(row['packaging_item_id']): row,
        };
        return [
          for (final item in packagingItems)
            PackagingStockItem(
              packagingItemId: item.id,
              packagingName: item.name,
              costInCents: item.costInCents,
              quantityOnHand: _int(stockById[item.id]?['quantity_on_hand']),
              updatedAt: _date(stockById[item.id]?['updated_at']),
            ),
        ];
      },
    );
  }

  @override
  Future<AppResult<void>> registerPackagingPurchase({
    required String packagingItemId,
    required int quantity,
    required String userId,
    String? notes,
  }) async {
    return const AppFailureResult<void>(
      AppFailure(
        code: 'admin_packaging_purchase_deprecated',
        message: 'Usa la compra por lote remota de inventario.',
      ),
    );
  }
}
