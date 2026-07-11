part of 'supabase_sync_remote_sender.dart';

extension on SupabaseSyncRemoteSender {
  Future<void> _pushBusinessSettings(SyncQueueItem item) async {
    final payload = item.payload;
    final restaurantId = _restaurantId;
    await _upsert('restaurants', {
      'id': restaurantId,
      'commercial_name': payload['businessName'],
      'legal_name': payload['legalName'],
      'tax_identifier': payload['taxNumber'],
      'phone': payload['phone'],
      'address': payload['address'],
      'show_company_data_on_pdf': payload['showCompanyInfoOnReceipts'],
      'updated_at': DateTime.now().toIso8601String(),
    });
    await _upsert('invoice_number_settings', {
      'restaurant_id': restaurantId,
      'prefix': payload['invoicePrefix'],
      'initial_number': payload['initialInvoiceNumber'],
      'next_number': payload['nextInvoiceNumber'],
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictColumn: 'restaurant_id');
  }

  Future<void> _pushPaymentMethod(SyncQueueItem item) async {
    if (item.operation == SyncOperation.delete) {
      final parentId = _optionalText(item.payload['parentId']);
      if (parentId != null) {
        await _patchWhere(
          'payment_methods',
          {
            'parent_id': parentId,
            'updated_at': DateTime.now().toIso8601String(),
          },
          {'parent_id': 'eq.${item.entityId}'},
        );
      }
      await _deleteById('payment_methods', item.entityId);
      return;
    }
    await _upsert('payment_methods', _paymentMethodPayload(item));
  }

  Future<void> _pushExpenseCategory(SyncQueueItem item) async {
    if (item.operation == SyncOperation.delete) {
      await _patchWhere(
        'expense_categories',
        {
          'parent_id': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        {'parent_id': 'eq.${item.entityId}'},
      );
      await _deleteById('expense_categories', item.entityId);
      return;
    }
    await _upsert('expense_categories', _expenseCategoryPayload(item));
  }

  Future<void> _replaceRolePermissions(SyncQueueItem item) async {
    final permissionCodes = _stringList(
      item.payload['permissionCodes'],
    ).toSet();

    await _adminRpc('app_replace_role_permissions', {
      'p_role_id': item.entityId,
      'p_permission_codes': permissionCodes.toList()..sort(),
    });
  }

  Future<void> _pushPermission(SyncQueueItem item) async {
    await _adminRpc('app_upsert_permission', {
      'p_payload': _permissionPayload(item),
    });
  }

  Future<void> _pushProfile(SyncQueueItem item) async {
    await _adminRpc('app_upsert_profile', {
      'p_payload': _profilePayload(item),
    });
  }

  Future<void> _pushRole(SyncQueueItem item) async {
    await _adminRpc('app_upsert_role', {
      'p_payload': _rolePayload(item),
    });
  }

  Future<void> _pushProductCategory(SyncQueueItem item) async {
    if (item.operation == SyncOperation.delete) {
      final parentId = _optionalText(item.payload['parentId']);
      if (parentId == null) {
        throw StateError('No se puede eliminar una categoria raiz.');
      }
      final now = DateTime.now().toIso8601String();
      await _patchWhere(
        'product_categories',
        {'parent_id': parentId, 'updated_at': now},
        {'parent_id': 'eq.${item.entityId}'},
      );
      await _patchWhere(
        'products',
        {'category_id': parentId, 'updated_at': now},
        {'category_id': 'eq.${item.entityId}'},
      );
      await _deleteById('product_categories', item.entityId);
      return;
    }
    await _upsert('product_categories', _productCategoryPayload(item));
  }

  Future<void> _pushProduct(SyncQueueItem item) async {
    await _upsert('products', _productPayload(item));

    final groupIds = _stringList(item.payload['modifierGroupIds']);
    await _deleteWhere(
      'product_modifier_groups',
      {'product_id': 'eq.${item.entityId}'},
    );

    var displayOrder = 0;
    for (final groupId in groupIds) {
      await _upsert(
        'product_modifier_groups',
        {
          'restaurant_id': _restaurantId,
          'product_id': item.entityId,
          'modifier_group_id': groupId,
          'display_order': displayOrder,
        },
        conflictColumn: 'product_id,modifier_group_id',
      );
      displayOrder++;
    }
  }
}
