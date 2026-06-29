import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';
import 'package:uuid/uuid.dart';

/// Sends queued local operations to Supabase through PostgREST.
final class SupabaseSyncRemoteSender implements ISyncRemoteSender {
  /// Creates a Supabase remote sender.
  SupabaseSyncRemoteSender({
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required http.Client client,
    Uuid uuid = const Uuid(),
  }) : _config = config,
       _restaurantService = restaurantService,
       _client = client,
       _uuid = uuid;

  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final http.Client _client;
  final Uuid _uuid;

  String? _accessToken;
  String? _remoteUserId;
  DateTime? _expiresAt;

  @override
  Future<void> push(SyncQueueItem item) async {
    _ensureConfigured();

    switch (item.entityType) {
      case 'business_settings':
        await _pushBusinessSettings(item);
      case 'cash_register_sessions':
        await _upsert(
          'cash_register_sessions',
          await _cashRegisterSessionPayload(item),
        );
      case 'exchange_rates':
        await _upsert(
          'exchange_rates',
          _exchangeRatePayload(item),
          conflictColumn: 'restaurant_id,currency_code,business_date',
        );
      case 'expense_categories':
        await _pushExpenseCategory(item);
      case 'modifier_groups':
        await _upsert('modifier_groups', _modifierGroupPayload(item));
      case 'modifier_options':
        await _upsert('modifier_options', _modifierOptionPayload(item));
      case 'operating_expenses':
        await _upsert(
          'operating_expenses',
          await _operatingExpensePayload(item),
        );
      case 'payment_methods':
        await _pushPaymentMethod(item);
      case 'product_categories':
        await _pushProductCategory(item);
      case 'products':
        await _pushProduct(item);
      case 'restaurant_tables':
        await _upsert('restaurant_tables', _restaurantTablePayload(item));
      case 'sales':
        await _pushSale(item);
      case 'table_accounts':
        await _upsert('table_accounts', await _tableAccountPayload(item));
      case 'audit_logs':
        await _upsert('audit_logs', _auditLogPayload(item));
      case 'permissions':
      case 'profiles':
      case 'role_permissions':
      case 'roles':
        return;
      default:
        throw UnsupportedError(
          'Entidad no soportada para sync remoto: ${item.entityType}.',
        );
    }
  }

  void _ensureConfigured() {
    if (!_config.isConfigured || !_restaurantService.isConfigured) {
      throw StateError(
        'Supabase remoto no esta configurado para este APK.',
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
      await _deleteById('payment_methods', item.entityId);
      return;
    }
    await _upsert('payment_methods', _paymentMethodPayload(item));
  }

  Future<void> _pushExpenseCategory(SyncQueueItem item) async {
    if (item.operation == SyncOperation.delete) {
      await _deleteById('expense_categories', item.entityId);
      return;
    }
    await _upsert('expense_categories', _expenseCategoryPayload(item));
  }

  Future<void> _pushProductCategory(SyncQueueItem item) async {
    if (item.operation == SyncOperation.delete) {
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

    await _upsert('sales', {
      'id': saleId,
      'local_id': salePayload['id'],
      'restaurant_id': _restaurantId,
      'cash_register_session_id': salePayload['cashRegisterSessionId'],
      'table_id': salePayload['tableId'],
      'table_account_id': tableAccountId,
      'account_name': salePayload['tableAccountId'],
      'user_id': remoteUserId,
      'payment_method_id': salePayload['paymentMethodId'],
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

    final voidPayload = _mapPayload(item.payload['void']);
    if (voidPayload.isNotEmpty) {
      await _upsert(
        'sale_voids',
        {
          'sale_id': saleId,
          'restaurant_id': _restaurantId,
          'cash_register_session_id': salePayload['cashRegisterSessionId'],
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
      'option_groups': payload['optionGroups'] ?? const <Object?>[],
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
    SyncQueueItem item,
  ) async {
    final payload = item.payload;
    final status = payload['status']?.toString();
    return {
      'id': payload['id'],
      'restaurant_id': _restaurantId,
      'cashier_user_id': await _authUserId(),
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

  Future<void> _deleteById(String table, String id) async {
    final response = await _client.delete(
      _config.restUri(table, {'id': 'eq.$id'}),
      headers: await _headers(prefer: 'return=minimal'),
    );
    _ensureSuccess(response, table);
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
    final currentToken = _accessToken;
    final currentExpiration = _expiresAt;
    if (currentToken != null &&
        currentExpiration != null &&
        currentExpiration.isAfter(
          DateTime.now().add(const Duration(minutes: 2)),
        )) {
      return currentToken;
    }

    final response = await _client.post(
      _config.passwordGrantUri,
      headers: {
        'apikey': _config.publishableKey,
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({
        'email': _config.authEmail,
        'password': _config.authPassword,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'No se pudo autenticar el usuario tecnico de Supabase '
        '(${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw StateError('Respuesta de autenticacion Supabase invalida.');
    }

    final token = decoded['access_token'];
    final expiresIn = decoded['expires_in'];
    final user = decoded['user'];
    if (token is! String || token.isEmpty) {
      throw StateError('Supabase no devolvio access_token.');
    }
    if (user is Map<String, Object?> && user['id'] is String) {
      _remoteUserId = user['id']! as String;
    }
    _accessToken = token;
    _expiresAt = DateTime.now().add(
      Duration(seconds: expiresIn is int ? expiresIn : 3600),
    );
    return token;
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
