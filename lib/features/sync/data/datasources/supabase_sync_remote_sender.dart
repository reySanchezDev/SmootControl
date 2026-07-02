import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';
import 'package:uuid/uuid.dart';

/// Sends queued local operations to Supabase through PostgREST.
final class SupabaseSyncRemoteSender implements ISyncRemoteSender {
  /// Creates a Supabase remote sender.
  SupabaseSyncRemoteSender({
    required AppDatabase database,
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
    Uuid uuid = const Uuid(),
  }) : _database = database,
       _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client,
       _uuid = uuid;

  final AppDatabase _database;
  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final CurrentRemoteSessionService _remoteSessionService;
  final http.Client _client;
  final Uuid _uuid;

  String? _remoteUserId;
  final Map<String, String> _cashRegisterSessionAliases = {};

  @override
  Future<void> push(SyncQueueItem item) async {
    _ensureConfigured();

    switch (item.entityType) {
      case 'business_settings':
        await _pushBusinessSettings(item);
      case 'cash_register_sessions':
        await _pushCashRegisterSession(item);
      case 'exchange_rates':
        await _upsert(
          'exchange_rates',
          _exchangeRatePayload(item),
          conflictColumn: 'restaurant_id,currency_code,business_date',
        );
      case 'expense_categories':
        await _pushExpenseCategory(item);
      case 'inventory_movements':
        await _pushInventoryMovement(item);
      case 'modifier_groups':
        await _upsert('modifier_groups', _modifierGroupPayload(item));
      case 'modifier_options':
        await _upsert('modifier_options', _modifierOptionPayload(item));
      case 'operating_expenses':
        if (_remoteSessionService.hasUsableToken) {
          await _upsert(
            'operating_expenses',
            await _operatingExpensePayload(item),
          );
        } else {
          await _pushOperatingExpenseWithDevice(item);
        }
      case 'payment_methods':
        await _pushPaymentMethod(item);
      case 'packaging_items':
        await _upsert('packaging_items', _packagingItemPayload(item));
      case 'packaging_movements':
        await _pushPackagingMovement(item);
      case 'product_packaging_rules':
        await _upsert(
          'product_packaging_rules',
          _productPackagingRulePayload(item),
        );
      case 'product_categories':
        await _pushProductCategory(item);
      case 'products':
        await _pushProduct(item);
      case 'sales_types':
        await _upsert('sales_types', _salesTypePayload(item));
      case 'restaurant_tables':
        await _upsert('restaurant_tables', _restaurantTablePayload(item));
      case 'sales':
        await _pushSale(item);
      case 'table_accounts':
        if (_remoteSessionService.hasUsableToken) {
          await _upsert('table_accounts', await _tableAccountPayload(item));
        } else {
          await _pushTableAccountWithDevice(item);
        }
      case 'audit_logs':
        await _upsert('audit_logs', _auditLogPayload(item));
      case 'profiles':
        await _upsert('profiles', _profilePayload(item));
      case 'roles':
        return;
      case 'role_permissions':
        return;
      case 'permissions':
        return;
      default:
        throw UnsupportedError(
          'Entidad no soportada para sync remoto: ${item.entityType}.',
        );
    }
  }

  void _ensureConfigured() {
    if (!(_remoteSessionService.hasUsableToken &&
            _config.isConfigured &&
            _restaurantService.isConfigured) &&
        !(_config.isConfigured && _restaurantService.isConfigured)) {
      throw StateError(
        'Supabase no esta configurado para sincronizar.',
      );
    }
  }

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
    if (groupIds.isEmpty) return;

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

  Future<void> _pushSale(SyncQueueItem item) async {
    if (await _hasDeviceCredentials()) {
      await _pushSaleWithDevice(item);
      return;
    }

    if (!_remoteSessionService.hasUsableToken) {
      await _pushSaleWithDevice(item);
      return;
    }

    final salePayload = _mapPayload(item.payload['sale']);
    final itemPayloads = _listPayload(item.payload['items']);
    final remoteUserId = await _authUserId();
    final totalCost = itemPayloads.fold<int>(
      0,
      (total, saleItem) {
        final quantity = _intValue(saleItem['quantity']);
        final cost = _intValue(saleItem['unitCostInCents']);
        return total + (quantity * cost);
      },
    );
    final totalAmount = _intValue(salePayload['totalInCents']);
    final saleId = _remoteUuid(salePayload['id'], scope: 'sales');
    final tableAccountId = _nullableRemoteUuid(
      salePayload['tableAccountId'],
      scope: 'table_accounts',
    );
    final cashRegisterSessionId = await _cashRegisterSessionIdForSale(
      salePayload,
    );

    await _upsert('sales', {
      'id': saleId,
      'local_id': salePayload['id'],
      'restaurant_id': _restaurantId,
      'cash_register_session_id': cashRegisterSessionId,
      'table_id': salePayload['tableId'],
      'table_account_id': tableAccountId,
      'account_name': salePayload['tableAccountId'],
      'user_id': remoteUserId,
      'payment_method_id': salePayload['paymentMethodId'],
      'sales_type_id': salePayload['salesTypeId'],
      'sales_type_name': salePayload['salesTypeName'],
      'payment_reference': salePayload['paymentReference'],
      'invoice_number': salePayload['invoiceNumber'],
      'total_amount': _money(totalAmount),
      'total_cost': _money(totalCost),
      'gross_profit': _money(totalAmount - totalCost),
      'status': salePayload['status'],
      'sync_status': 'synced',
      'sold_at': salePayload['createdAt'],
      'updated_at': DateTime.now().toIso8601String(),
    });

    for (final saleItem in itemPayloads) {
      await _upsert('sale_items', _saleItemPayload(saleItem, saleId));
    }

    for (final movement in _listPayload(item.payload['inventoryMovements'])) {
      await _applyInventoryMovement(movement);
    }
    for (final movement in _listPayload(item.payload['packagingMovements'])) {
      await _applyPackagingMovement(movement);
    }

    final voidPayload = _mapPayload(item.payload['void']);
    if (voidPayload.isNotEmpty) {
      await _upsert(
        'sale_voids',
        {
          'sale_id': saleId,
          'restaurant_id': _restaurantId,
          'cash_register_session_id': cashRegisterSessionId,
          'voided_by_user_id': remoteUserId,
          'reason': voidPayload['reason'] ?? 'Anulacion local',
          'original_total_amount': _money(totalAmount),
          'original_payment_method_id': salePayload['paymentMethodId'],
          'original_payment_reference': salePayload['paymentReference'],
          'sync_status': 'synced',
        },
        conflictColumn: 'sale_id',
      );
    }
  }

  Future<void> _pushInventoryMovement(SyncQueueItem item) async {
    await _applyInventoryMovement(item.payload);
  }

  Future<void> _pushPackagingMovement(SyncQueueItem item) async {
    await _applyPackagingMovement(item.payload);
  }

  Future<void> _pushCashRegisterSession(SyncQueueItem item) async {
    if (await _hasDeviceCredentials()) {
      await _pushCashRegisterSessionWithDevice(item);
      return;
    }

    if (!_remoteSessionService.hasUsableToken) {
      await _pushCashRegisterSessionWithDevice(item);
      return;
    }

    final payload = await _cashRegisterSessionPayload(item);
    final response = await _client.post(
      _config.restUri('cash_register_sessions', {'on_conflict': 'id'}),
      headers: await _headers(
        prefer: 'resolution=merge-duplicates,return=minimal',
      ),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final localId = _optionalText(item.payload['id']);
      if (localId != null) {
        _cashRegisterSessionAliases[localId] =
            _optionalText(payload['id']) ?? localId;
      }
      return;
    }

    if (!_isOpenCashRegisterDuplicate(response)) {
      _ensureSuccess(response, 'cash_register_sessions');
      return;
    }

    final localId = _optionalText(item.payload['id']);
    final cashierId = _optionalText(payload['cashier_user_id']);
    final businessDate = _dateOnly(payload['business_date']);
    if (localId == null || cashierId == null || businessDate == null) {
      _ensureSuccess(response, 'cash_register_sessions');
      return;
    }

    final remoteSessionId = await _findOpenCashRegisterSessionId(
      cashierId: cashierId,
      businessDate: businessDate,
    );
    if (remoteSessionId == null) {
      _ensureSuccess(response, 'cash_register_sessions');
      return;
    }
    _cashRegisterSessionAliases[localId] = remoteSessionId;
  }

  Future<void> _pushCashRegisterSessionWithDevice(SyncQueueItem item) async {
    final payload = await _cashRegisterSessionPayload(
      item,
      allowAuthFallback: false,
    );
    final result = await _deviceRpc(
      'pos_sync_cash_register_session',
      {'p_payload': payload},
    );
    final localId = _optionalText(item.payload['id']);
    final remoteId = _optionalText(result['remote_id']);
    if (localId != null && remoteId != null) {
      _cashRegisterSessionAliases[localId] = remoteId;
    }
  }

  Future<void> _pushSaleWithDevice(SyncQueueItem item) async {
    final salePayload = _mapPayload(item.payload['sale']);
    final itemPayloads = _listPayload(item.payload['items']);
    final cashierId =
        _optionalText(salePayload['cashierId']) ?? await _deviceUserId();
    final totalCost = itemPayloads.fold<int>(
      0,
      (total, saleItem) {
        final quantity = _intValue(saleItem['quantity']);
        final cost = _intValue(saleItem['unitCostInCents']);
        return total + (quantity * cost);
      },
    );
    final totalAmount = _intValue(salePayload['totalInCents']);
    final saleId = _remoteUuid(salePayload['id'], scope: 'sales');
    final tableAccountId = _nullableRemoteUuid(
      salePayload['tableAccountId'],
      scope: 'table_accounts',
    );
    final cashRegisterSessionId =
        _cashRegisterSessionAliases[_optionalText(
          salePayload['cashRegisterSessionId'],
        )] ??
        _optionalText(salePayload['cashRegisterSessionId']);

    final result = await _deviceRpc('pos_sync_sale', {
      'p_payload': {
        'sale': {
          'id': saleId,
          'local_id': salePayload['id'],
          'cash_register_session_id': cashRegisterSessionId,
          'business_date': _dateOnly(salePayload['businessDate']),
          'table_id': salePayload['tableId'],
          'table_account_id': tableAccountId,
          'account_name': salePayload['tableAccountId'],
          'user_id': cashierId,
          'payment_method_id': salePayload['paymentMethodId'],
          'sales_type_id': salePayload['salesTypeId'],
          'sales_type_name': salePayload['salesTypeName'],
          'payment_reference': salePayload['paymentReference'],
          'invoice_number': salePayload['invoiceNumber'],
          'total_amount': _money(totalAmount),
          'total_cost': _money(totalCost),
          'gross_profit': _money(totalAmount - totalCost),
          'status': salePayload['status'],
          'sold_at': salePayload['createdAt'],
        },
        'items': itemPayloads.map((payload) {
          return _saleItemPayload(payload, saleId);
        }).toList(),
        'inventory_movements': _listPayload(
          item.payload['inventoryMovements'],
        ).map(_deviceInventoryMovementPayload).toList(),
        'packaging_movements': _listPayload(
          item.payload['packagingMovements'],
        ).map(_devicePackagingMovementPayload).toList(),
        'void': _mapPayload(item.payload['void']),
      },
    });
    await _applyRemoteSaleResult(
      result: result,
      salePayload: salePayload,
    );
  }

  Future<void> _pushOperatingExpenseWithDevice(SyncQueueItem item) async {
    final payload = item.payload;
    final cashRegisterSessionId =
        _cashRegisterSessionAliases[_optionalText(
          payload['cashRegisterSessionId'],
        )] ??
        _optionalText(payload['cashRegisterSessionId']);
    final createdBy =
        _optionalText(payload['createdBy']) ?? await _deviceUserId();

    await _deviceRpc('pos_sync_operating_expense', {
      'p_payload': {
        'id': _remoteUuid(payload['id'], scope: 'operating_expenses'),
        'local_id': payload['id'],
        'expense_category_id': payload['categoryId'],
        'cash_register_session_id': cashRegisterSessionId,
        'created_by_user_id': createdBy,
        'description': payload['description'],
        'amount': _money(_intValue(payload['amountInCents'])),
        'spent_at': payload['createdAt'],
      },
    });
  }

  Future<void> _pushTableAccountWithDevice(SyncQueueItem item) async {
    final payload = item.payload;
    await _deviceRpc('pos_sync_table_account', {
      'p_payload': {
        'id': _remoteUuid(payload['id'], scope: 'table_accounts'),
        'table_id': payload['table_id'],
        'name': payload['name'],
        'status': payload['status'],
        'created_by_user_id': await _deviceUserId(),
      },
    });
  }

  Map<String, Object?> _deviceInventoryMovementPayload(
    Map<String, Object?> payload,
  ) {
    return {
      'id': payload['id'],
      'product_id': payload['productId'],
      'movement_type': payload['movementType'],
      'quantity_delta': _intValue(payload['quantityDelta']),
      'reference_type': payload['referenceType'],
      'reference_id': payload['referenceId'],
      'user_id': payload['userId'],
      'notes': payload['notes'],
      'created_at': payload['createdAt'],
    };
  }

  Map<String, Object?> _devicePackagingMovementPayload(
    Map<String, Object?> payload,
  ) {
    return {
      'id': payload['id'],
      'packaging_item_id': payload['packagingItemId'],
      'movement_type': payload['movementType'],
      'quantity_delta': _intValue(payload['quantityDelta']),
      'unit_cost': _money(_intValue(payload['unitCostInCents'])),
      'reference_type': payload['referenceType'],
      'reference_id': payload['referenceId'],
      'user_id': payload['userId'],
      'notes': payload['notes'],
      'created_at': payload['createdAt'],
    };
  }

  Future<String?> _cashRegisterSessionIdForSale(
    Map<String, Object?> salePayload,
  ) async {
    final localId = _optionalText(salePayload['cashRegisterSessionId']);
    if (localId == null) return null;

    final alias = _cashRegisterSessionAliases[localId];
    if (alias != null) return alias;

    final cashierId = _optionalText(salePayload['cashierId']);
    final businessDate = _dateOnly(salePayload['businessDate']);
    if (cashierId == null || businessDate == null) return localId;

    final remoteSessionId = await _findOpenCashRegisterSessionId(
      cashierId: cashierId,
      businessDate: businessDate,
    );
    if (remoteSessionId == null) return localId;

    _cashRegisterSessionAliases[localId] = remoteSessionId;
    return remoteSessionId;
  }

  bool _isOpenCashRegisterDuplicate(http.Response response) {
    if (response.statusCode != 409) return false;
    final body = response.body;
    return body.contains('cash_register_one_open_per_user_day_idx') ||
        body.contains('duplicate key value') &&
            body.contains('cash_register_sessions');
  }

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
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'parent_id': payload['parentId'],
      'name': payload['name'],
      'is_active': payload['isActive'],
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

  Map<String, Object?> _saleItemPayload(
    Map<String, Object?> payload,
    String saleId,
  ) {
    final quantity = _intValue(payload['quantity']);
    final unitPrice = _intValue(payload['unitPriceInCents']);
    final unitCost = _intValue(payload['unitCostInCents']);
    final subtotal = quantity * unitPrice;
    final totalCost = quantity * unitCost;
    return {
      'id': _remoteUuid(payload['id'], scope: 'sale_items'),
      'sale_id': saleId,
      'product_id': payload['productId'],
      'table_account_id': _nullableRemoteUuid(
        payload['tableAccountId'],
        scope: 'table_accounts',
      ),
      'product_code': payload['productId'],
      'product_name': payload['productName'],
      'category_name': payload['categoryName'],
      'selected_options_label': payload['selectedOptionsLabel'],
      'quantity': quantity,
      'unit_price': _money(unitPrice),
      'unit_cost': _money(unitCost),
      'subtotal': _money(subtotal),
      'gross_profit': _money(subtotal - totalCost),
      'created_at': payload['createdAt'],
    };
  }

  Future<void> _upsert(
    String table,
    Map<String, Object?> payload, {
    String conflictColumn = 'id',
  }) async {
    final response = await _client.post(
      _config.restUri(table, {'on_conflict': conflictColumn}),
      headers: await _headers(
        prefer: 'resolution=merge-duplicates,return=minimal',
      ),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, table);
  }

  Future<void> _applyInventoryMovement(Map<String, Object?> payload) async {
    if (payload.isEmpty) return;
    final response = await _client.post(
      _config.restUri('rpc/apply_inventory_movement'),
      headers: await _headers(),
      body: jsonEncode({
        'p_id': payload['id'],
        'p_restaurant_id': _restaurantId,
        'p_product_id': payload['productId'],
        'p_movement_type': payload['movementType'],
        'p_quantity_delta': _intValue(payload['quantityDelta']),
        'p_reference_type': payload['referenceType'],
        'p_reference_id': payload['referenceId'],
        'p_user_id': payload['userId'],
        'p_notes': payload['notes'],
        'p_created_at': payload['createdAt'],
      }),
    );
    _ensureSuccess(response, 'inventory_movements');
  }

  Future<void> _applyPackagingMovement(Map<String, Object?> payload) async {
    if (payload.isEmpty) return;
    final response = await _client.post(
      _config.restUri('rpc/apply_packaging_movement'),
      headers: await _headers(),
      body: jsonEncode({
        'p_id': payload['id'],
        'p_restaurant_id': _restaurantId,
        'p_packaging_item_id': payload['packagingItemId'],
        'p_movement_type': payload['movementType'],
        'p_quantity_delta': _intValue(payload['quantityDelta']),
        'p_unit_cost': _money(_intValue(payload['unitCostInCents'])),
        'p_reference_type': payload['referenceType'],
        'p_reference_id': payload['referenceId'],
        'p_user_id': payload['userId'],
        'p_notes': payload['notes'],
        'p_created_at': payload['createdAt'],
      }),
    );
    _ensureSuccess(response, 'packaging_movements');
  }

  Future<void> _deleteById(String table, String id) async {
    final response = await _client.delete(
      _config.restUri(table, {'id': 'eq.$id'}),
      headers: await _headers(prefer: 'return=minimal'),
    );
    _ensureSuccess(response, table);
  }

  Future<void> _patchWhere(
    String table,
    Map<String, Object?> payload,
    Map<String, String> query,
  ) async {
    final response = await _client.patch(
      _config.restUri(table, query),
      headers: await _headers(prefer: 'return=minimal'),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, table);
  }

  Future<String?> _findOpenCashRegisterSessionId({
    required String cashierId,
    required String businessDate,
  }) async {
    final rows = await _getRows('cash_register_sessions', {
      'restaurant_id': 'eq.$_restaurantId',
      'cashier_user_id': 'eq.$cashierId',
      'business_date': 'eq.$businessDate',
      'status': 'eq.open',
      'select': 'id',
      'limit': '1',
    });
    if (rows.isEmpty) return null;
    return _optionalText(rows.first['id']);
  }

  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> query,
  ) async {
    final response = await _client.get(
      _config.restUri(table, query),
      headers: await _headers(),
    );
    _ensureSuccess(response, table);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<Object?, Object?>>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  Future<Map<String, String>> _headers({String? prefer}) async {
    final headers = <String, String>{
      'apikey': _config.publishableKey,
      'authorization': 'Bearer ${await _authToken()}',
      'content-type': 'application/json',
      'accept': 'application/json',
    };
    if (prefer != null) {
      headers['prefer'] = prefer;
    }
    return headers;
  }

  Future<String> _authToken() async {
    final sessionToken = _remoteSessionService.accessToken;
    if (sessionToken != null) {
      _remoteUserId = _remoteSessionService.userId;
      return sessionToken;
    }

    throw StateError(
      'Inicia sesion como administrador remoto para sincronizar.',
    );
  }

  Future<String> _authUserId() async {
    final current = _remoteUserId;
    if (current != null && current.isNotEmpty) return current;
    await _authToken();
    final resolved = _remoteUserId;
    if (resolved == null || resolved.isEmpty) {
      throw StateError('No se pudo resolver el usuario remoto autenticado.');
    }
    return resolved;
  }

  void _ensureSuccess(http.Response response, String table) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw StateError(
      'Supabase rechazo sync en $table (${response.statusCode}): '
      '${response.body}',
    );
  }

  String get _restaurantId => _restaurantService.restaurantId;

  Future<Map<String, Object?>> _deviceRpc(
    String functionName,
    Map<String, Object?> body,
  ) async {
    final credentials = await _deviceCredentials();
    final response = await _client.post(
      _config.rpcUri(functionName),
      headers: {
        'apikey': _config.publishableKey,
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({
        'p_restaurant_id': _restaurantId,
        'p_device_id': credentials.deviceId,
        'p_device_secret': credentials.deviceSecret,
        ...body,
      }),
    );
    _ensureSuccess(response, functionName);
    if (response.body.trim().isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  Future<_DeviceSyncCredentials> _deviceCredentials() async {
    final state = await (_database.select(
      _database.localDeviceState,
    )..where((row) => row.id.equals('default'))).getSingleOrNull();
    final deviceId = _optionalText(state?.syncDeviceId ?? state?.deviceId);
    final deviceSecret = _optionalText(state?.syncDeviceSecret);
    if (deviceId == null || deviceSecret == null) {
      throw StateError(
        'Este dispositivo no tiene credencial de sincronizacion POS. '
        'Inicializa la tableta desde Supabase nuevamente.',
      );
    }
    return _DeviceSyncCredentials(
      deviceId: deviceId,
      deviceSecret: deviceSecret,
    );
  }

  Future<bool> _hasDeviceCredentials() async {
    final state = await (_database.select(
      _database.localDeviceState,
    )..where((row) => row.id.equals('default'))).getSingleOrNull();
    final deviceId = _optionalText(state?.syncDeviceId ?? state?.deviceId);
    final deviceSecret = _optionalText(state?.syncDeviceSecret);
    return deviceId != null && deviceSecret != null;
  }

  Future<void> _applyRemoteSaleResult({
    required Map<String, Object?> result,
    required Map<String, Object?> salePayload,
  }) async {
    final localSaleId = _optionalText(salePayload['id']);
    final remoteInvoiceNumber = _optionalText(result['invoice_number']);
    if (localSaleId == null || remoteInvoiceNumber == null) return;

    final now = DateTime.now();
    final currentInvoiceNumber = _optionalText(salePayload['invoiceNumber']);
    if (currentInvoiceNumber != remoteInvoiceNumber) {
      await (_database.update(
        _database.localSales,
      )..where((sale) => sale.id.equals(localSaleId))).write(
        LocalSalesCompanion(
          invoiceNumber: Value(remoteInvoiceNumber),
          syncStatus: const Value('synced'),
          syncError: const Value(null),
          updatedAt: Value(now),
          syncedAt: Value(now),
        ),
      );
    }

    final nextInvoiceNumber = _nextInvoiceNumberAfter(remoteInvoiceNumber);
    if (nextInvoiceNumber == null) return;
    final settings = await (_database.select(
      _database.localBusinessSettings,
    )..where((row) => row.id.equals('default'))).getSingleOrNull();
    if (settings == null || settings.nextInvoiceNumber >= nextInvoiceNumber) {
      return;
    }

    await (_database.update(
      _database.localBusinessSettings,
    )..where((row) => row.id.equals('default'))).write(
      LocalBusinessSettingsCompanion(
        nextInvoiceNumber: Value(nextInvoiceNumber),
        updatedAt: Value(now),
        syncedAt: Value(now),
      ),
    );
  }

  int? _nextInvoiceNumberAfter(String invoiceNumber) {
    final match = RegExp(r'(\d+)$').firstMatch(invoiceNumber.trim());
    if (match == null) return null;
    final value = int.tryParse(match.group(1)!);
    if (value == null) return null;
    return value + 1;
  }

  Future<String> _deviceUserId() async {
    final state = await (_database.select(
      _database.localDeviceState,
    )..where((row) => row.id.equals('default'))).getSingleOrNull();
    final userId = _optionalText(state?.initializedByUserId);
    if (userId == null) {
      throw StateError('No se pudo resolver el usuario local del dispositivo.');
    }
    return userId;
  }

  num _money(int cents) => cents / 100;

  num? _optionalMoney(Object? value) {
    if (value == null) return null;
    return _money(_intValue(value));
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String? _dateOnly(Object? value) {
    final text = value?.toString();
    if (text == null || text.length < 10) return text;
    return text.substring(0, 10);
  }

  String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Map<String, Object?> _mapPayload(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  List<Map<String, Object?>> _listPayload(Object? value) {
    if (value is! List) return const [];
    return value.map(_mapPayload).toList();
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  String? _uuidOrNull(Object? value) {
    final text = value?.toString();
    if (text == null) return null;
    final normalized = text.trim();
    if (RegExp(
      '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-'
      '[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      '[0-9a-fA-F]{12}'
      r'$',
    ).hasMatch(normalized)) {
      return normalized;
    }
    return null;
  }

  String _remoteUuid(Object? value, {required String scope}) {
    final directUuid = _uuidOrNull(value);
    if (directUuid != null) return directUuid;

    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      throw StateError('No se pudo generar UUID remoto para $scope.');
    }

    return _uuid.v5(
      Namespace.url.value,
      'smoo-control:$_restaurantId:$scope:$text',
    );
  }

  String? _nullableRemoteUuid(Object? value, {required String scope}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;

    return _remoteUuid(text, scope: scope);
  }
}

final class _DeviceSyncCredentials {
  const _DeviceSyncCredentials({
    required this.deviceId,
    required this.deviceSecret,
  });

  final String deviceId;
  final String deviceSecret;
}
