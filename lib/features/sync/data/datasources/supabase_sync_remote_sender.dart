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

part 'supabase_sync_remote_sender_admin_part.dart';
part 'supabase_sync_remote_sender_cash_part.dart';
part 'supabase_sync_remote_sender_http_part.dart';
part 'supabase_sync_remote_sender_models_part.dart';
part 'supabase_sync_remote_sender_payloads_part.dart';
part 'supabase_sync_remote_sender_staff_part.dart';
part 'supabase_sync_remote_sender_utils_part.dart';
part 'supabase_sync_remote_sender_sales_part.dart';

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
      case 'salary_advances':
        await _pushSalaryAdvance(item);
      case 'table_accounts':
        if (_remoteSessionService.hasUsableToken) {
          await _upsert('table_accounts', await _tableAccountPayload(item));
        } else {
          await _pushTableAccountWithDevice(item);
        }
      case 'audit_logs':
        await _upsert('audit_logs', _auditLogPayload(item));
      case 'profiles':
        await _pushProfile(item);
      case 'roles':
        await _pushRole(item);
      case 'role_permissions':
        await _replaceRolePermissions(item);
      case 'permissions':
        await _pushPermission(item);
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
}
