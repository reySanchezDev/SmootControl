part of 'supabase_sync_remote_sender.dart';

extension on SupabaseSyncRemoteSender {
  Map<String, Object?> _auditLogPayload(SyncQueueItem item) {
    final payload = item.payload;
    return {
      'id': item.entityId,
      'restaurant_id': _restaurantId,
      'actor_user_id': null,
      'action': payload['action'],
      'entity_name': payload['entityName'],
      'entity_id': _uuidOrNull(payload['entityId']),
      'details': payload['details'] ?? const <String, Object?>{},
      'created_at': payload['occurredAt'],
    };
  }

  Map<String, Object?> _profilePayload(SyncQueueItem item) {
    final payload = item.payload;
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'role_id': payload['roleId'],
      'display_name': payload['displayName'],
      'email': payload['email'],
      'is_active': payload['isActive'],
      'is_pos_user': payload['isPosUser'],
      'pin_salt': payload['pinSalt'],
      'pin_hash': payload['pinHash'],
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _permissionPayload(SyncQueueItem item) {
    final payload = item.payload;
    return {
      'code': payload['code'] ?? item.entityId,
      'name': payload['name'] ?? item.entityId,
      'description': payload['description'],
    };
  }

  Map<String, Object?> _rolePayload(SyncQueueItem item) {
    final payload = item.payload;
    final id = payload['id'] ?? item.entityId;
    return {
      'id': id,
      'restaurant_id': _restaurantId,
      'code': _roleCode(id),
      'name': payload['name'],
      'description': payload['description'],
      'is_system': payload['isSystem'] ?? false,
      'is_active': payload['isActive'] ?? true,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _productCategoryPayload(SyncQueueItem item) {
    final payload = item.payload;
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'parent_id': payload['parentId'],
      'name': payload['name'],
      'display_order': payload['sortOrder'],
      'is_active': payload['isActive'],
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _productPayload(SyncQueueItem item) {
    final payload = item.payload;
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'category_id': payload['categoryId'],
      'code': payload['id'],
      'name': payload['name'],
      'cost': _money(_intValue(payload['costInCents'])),
      'price': _money(_intValue(payload['priceInCents'])),
      'is_active': payload['isActive'],
      'is_available_in_pos': payload['isAvailableInPos'],
      'tracks_inventory': payload['tracksInventory'] ?? false,
      'option_groups': payload['optionGroups'] ?? const <Object?>[],
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _salesTypePayload(SyncQueueItem item) {
    final payload = item.payload;
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'code': payload['code'],
      'name': payload['name'],
      'display_order': payload['displayOrder'],
      'is_default': payload['isDefault'],
      'is_active': payload['isActive'],
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _packagingItemPayload(SyncQueueItem item) {
    final payload = item.payload;
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'name': payload['name'],
      'cost': _money(_intValue(payload['costInCents'])),
      'tracks_stock': payload['tracksStock'],
      'is_active': payload['isActive'],
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _productPackagingRulePayload(SyncQueueItem item) {
    final payload = item.payload;
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'product_id': payload['productId'],
      'sales_type_id': payload['salesTypeId'],
      'packaging_item_id': payload['packagingItemId'],
      'quantity_per_unit': payload['quantityPerUnit'],
      'is_active': payload['isActive'],
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _modifierGroupPayload(SyncQueueItem item) {
    final payload = item.payload;
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'name': payload['name'],
      'is_required': payload['isRequired'],
      'display_order': payload['displayOrder'],
      'is_active': payload['isActive'],
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _expenseCategoryPayload(SyncQueueItem item) {
    final payload = item.payload;
    final parentId = payload['parentId'];
    final includeInCoverage =
        parentId != null && payload['includeInGrossProfitCoverage'] == true;
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'parent_id': parentId,
      'name': payload['name'],
      'is_active': payload['isActive'],
      'include_in_gross_profit_coverage': includeInCoverage,
      'coverage_expense_type': includeInCoverage
          ? payload['coverageType']
          : null,
      'coverage_estimated_amount': includeInCoverage
          ? _optionalMoney(payload['coverageEstimatedAmountInCents'])
          : null,
      'coverage_frequency': includeInCoverage
          ? payload['coverageFrequency']
          : null,
      'coverage_due_days': includeInCoverage
          ? payload['coverageDueDays'] ?? const <Object?>[]
          : const <Object?>[],
      'coverage_notes': includeInCoverage ? payload['coverageNotes'] : null,
      'coverage_is_active': includeInCoverage
          ? payload['coverageIsActive'] ?? true
          : true,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _exchangeRatePayload(SyncQueueItem item) {
    final payload = item.payload;
    return {
      'restaurant_id': _restaurantId,
      'currency_code': payload['currencyCode'],
      'business_date': _dateOnly(payload['businessDate']),
      'rate': _money(_intValue(payload['rateInCents'])),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _modifierOptionPayload(SyncQueueItem item) {
    final payload = item.payload;
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'group_id': payload['groupId'],
      'name': payload['name'],
      'price_delta': _money(_intValue(payload['priceDeltaInCents'])),
      'display_order': payload['displayOrder'],
      'is_active': payload['isActive'],
      'is_available_in_pos': payload['isAvailableInPos'],
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _paymentMethodPayload(SyncQueueItem item) {
    final payload = item.payload;
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'parent_id': payload['parentId'],
      'code': payload['id'],
      'name': payload['name'],
      'group_name': payload['groupName'],
      'currency_code': payload['currencyCode'],
      'display_order': payload['displayOrder'],
      'is_payment_target': payload['isPaymentTarget'],
      'affects_cash': payload['affectsCashRegister'],
      'requires_reference': payload['requiresReference'],
      'is_active': payload['isActive'],
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, Object?>> _cashRegisterSessionPayload(
    SyncQueueItem item, {
    bool allowAuthFallback = true,
  }) async {
    final payload = item.payload;
    final status = payload['status']?.toString();
    final cashierId =
        _optionalText(payload['cashierId']) ??
        (allowAuthFallback ? await _authUserId() : await _deviceUserId());
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'cashier_user_id': cashierId,
      'business_date': _dateOnly(payload['businessDate']),
      'opening_cash_amount': _money(_intValue(payload['openingCashInCents'])),
      'counted_cash_amount': _optionalMoney(
        payload['physicalClosingCashInCents'],
      ),
      'status': status,
      if (status == 'closed') 'closed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, Object?>> _operatingExpensePayload(
    SyncQueueItem item,
  ) async {
    final payload = item.payload;
    return {
      'id': payload['id'],
      'local_id': payload['id'],
      'restaurant_id': _restaurantId,
      'expense_category_id': payload['categoryId'],
      'cash_register_session_id': payload['cashRegisterSessionId'],
      'created_by_user_id': await _authUserId(),
      'description': payload['description'],
      'amount': _money(_intValue(payload['amountInCents'])),
      'sync_status': 'synced',
      'spent_at': payload['createdAt'],
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _restaurantTablePayload(SyncQueueItem item) {
    final payload = item.payload;
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'name': payload['name'],
      'display_name': payload['display_name'],
      'is_active': payload['is_active'],
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, Object?>> _tableAccountPayload(SyncQueueItem item) async {
    final payload = item.payload;
    return {
      'id': _remoteUuid(payload['id'], scope: 'table_accounts'),
      'restaurant_id': _restaurantId,
      'table_id': payload['table_id'],
      'name': payload['name'],
      'status': payload['status'],
      'created_by_user_id': await _authUserId(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
