import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/core/utils/business_date_formatter.dart';
import 'package:smoo_control/features/products/data/models/string_list_codec.dart';
import 'package:smoo_control/features/sync/domain/services/catalog_pull_summary.dart';
import 'package:smoo_control/features/sync/domain/services/i_catalog_pull_service.dart';

part 'supabase_catalog_pull_service_access_part.dart';
part 'supabase_catalog_pull_service_business_part.dart';
part 'supabase_catalog_pull_service_catalog_part.dart';
part 'supabase_catalog_pull_service_inventory_part.dart';
part 'supabase_catalog_pull_service_missing_part.dart';
part 'supabase_catalog_pull_service_models_part.dart';
part 'supabase_catalog_pull_service_payment_part.dart';
part 'supabase_catalog_pull_service_remote_part.dart';
part 'supabase_catalog_pull_service_session_part.dart';

/// Downloads Supabase operational catalog rows into the local POS database.
final class SupabaseCatalogPullService implements ICatalogPullService {
  /// Creates a Supabase catalog pull service.
  SupabaseCatalogPullService({
    required AppDatabase database,
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
  }) : _database = database,
       _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client;

  final AppDatabase _database;
  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final CurrentRemoteSessionService _remoteSessionService;
  final http.Client _client;

  String? _accessToken;
  DateTime? _expiresAt;
  bool _temporaryTokenOnly = false;
  Map<String, List<Map<String, Object?>>>? _deviceCatalogRows;

  @override
  Future<CatalogPullSummary> pullOperationalCatalog() {
    return pullScopes(CatalogPullScope.values.toSet());
  }

  /// Downloads the full operational catalog using a temporary admin token.
  Future<CatalogPullSummary> pullOperationalCatalogWithAccessToken(
    String accessToken,
  ) async {
    final previousToken = _accessToken;
    final previousExpiration = _expiresAt;
    final previousTemporaryTokenOnly = _temporaryTokenOnly;
    _accessToken = accessToken;
    _expiresAt = DateTime.now().add(const Duration(minutes: 55));
    _temporaryTokenOnly = true;
    try {
      return await pullOperationalCatalog();
    } finally {
      _accessToken = previousToken;
      _expiresAt = previousExpiration;
      _temporaryTokenOnly = previousTemporaryTokenOnly;
    }
  }

  @override
  Future<CatalogPullSummary> pullScopes(Set<CatalogPullScope> scopes) async {
    await _ensureCanPull();

    if (scopes.isEmpty) return const CatalogPullSummary.empty();

    _deviceCatalogRows = null;
    await _prepareDeviceCatalogIfNeeded();

    final effectiveScopes = {...scopes};
    if (effectiveScopes.contains(CatalogPullScope.products)) {
      effectiveScopes
        ..add(CatalogPullScope.catalog)
        ..add(CatalogPullScope.modifiers)
        ..add(CatalogPullScope.packaging);
    }

    final shouldRefreshBusinessSettings = effectiveScopes.contains(
      CatalogPullScope.businessSettings,
    );
    final shouldRefreshAccessControl = effectiveScopes.contains(
      CatalogPullScope.accessControl,
    );
    final shouldRefreshCatalog = effectiveScopes.contains(
      CatalogPullScope.catalog,
    );
    final shouldRefreshProducts = effectiveScopes.contains(
      CatalogPullScope.products,
    );
    final shouldRefreshModifiers = effectiveScopes.contains(
      CatalogPullScope.modifiers,
    );
    final shouldRefreshPaymentMethods = effectiveScopes.contains(
      CatalogPullScope.paymentMethods,
    );
    final shouldRefreshTables = effectiveScopes.contains(
      CatalogPullScope.tables,
    );
    final shouldRefreshExpenseCategories = effectiveScopes.contains(
      CatalogPullScope.expenseCategories,
    );
    final shouldRefreshExchangeRates = effectiveScopes.contains(
      CatalogPullScope.exchangeRates,
    );
    final shouldRefreshPackaging = effectiveScopes.contains(
      CatalogPullScope.packaging,
    );
    final shouldRefreshCashRegisterSessions = effectiveScopes.contains(
      CatalogPullScope.cashRegisterSessions,
    );
    final shouldRefreshStaff = effectiveScopes.contains(CatalogPullScope.staff);

    final restaurantRows = shouldRefreshBusinessSettings
        ? await _getRowsByQuery('restaurants', {
            'id': 'eq.${_restaurantService.restaurantId}',
            'select': '*',
          })
        : const <Map<String, Object?>>[];
    final invoiceSettings = shouldRefreshBusinessSettings
        ? await _getRows('invoice_number_settings')
        : const <Map<String, Object?>>[];
    final permissions = shouldRefreshAccessControl
        ? await _getRowsByQuery('permissions', {'select': '*'})
        : const <Map<String, Object?>>[];
    final restaurantRoles = shouldRefreshAccessControl
        ? await _getRows('roles')
        : const <Map<String, Object?>>[];
    final globalRoles = shouldRefreshAccessControl && restaurantRoles.isEmpty
        ? await _getGlobalRows('roles')
        : const <Map<String, Object?>>[];
    final roles = restaurantRoles.isEmpty ? globalRoles : restaurantRoles;
    final rolePermissions = shouldRefreshAccessControl
        ? await _getRowsByQuery('role_permissions', {
            'select': 'role_id,permission_id',
          })
        : const <Map<String, Object?>>[];
    final profiles = shouldRefreshAccessControl
        ? await _getRows('profiles')
        : const <Map<String, Object?>>[];
    final categories = shouldRefreshCatalog
        ? await _getRows('product_categories')
        : const <Map<String, Object?>>[];
    final modifierGroups = shouldRefreshModifiers
        ? await _getRows('modifier_groups')
        : const <Map<String, Object?>>[];
    final modifierOptions = shouldRefreshModifiers
        ? await _getRows('modifier_options')
        : const <Map<String, Object?>>[];
    final productModifierGroups = shouldRefreshProducts
        ? await _getRows(
            'product_modifier_groups',
            select: 'product_id,modifier_group_id,display_order',
          )
        : const <Map<String, Object?>>[];
    final products = shouldRefreshProducts
        ? await _getRowsByQuery('products', {
            'restaurant_id': 'eq.${_restaurantService.restaurantId}',
            'or': '(is_raw_material.eq.false,is_raw_material.is.null)',
            'select': '*',
          })
        : const <Map<String, Object?>>[];
    final inventoryStock = shouldRefreshProducts
        ? _stockForProducts(await _getRows('inventory_stock'), products)
        : const <Map<String, Object?>>[];
    if (shouldRefreshPackaging && _deviceCatalogRows == null) {
      await _ensureDefaultSalesTypes();
    }
    final salesTypes = shouldRefreshPackaging
        ? await _getRows('sales_types')
        : const <Map<String, Object?>>[];
    final packagingItems = shouldRefreshPackaging
        ? await _getRows('packaging_items')
        : const <Map<String, Object?>>[];
    final packagingRules = shouldRefreshPackaging
        ? await _getRows('product_packaging_rules')
        : const <Map<String, Object?>>[];
    final packagingStock = shouldRefreshPackaging
        ? await _getRows('packaging_stock')
        : const <Map<String, Object?>>[];
    final paymentMethods = shouldRefreshPaymentMethods
        ? await _getRowsIncludingGlobal('payment_methods')
        : const <Map<String, Object?>>[];
    final tables = shouldRefreshTables
        ? await _getRows('restaurant_tables')
        : const <Map<String, Object?>>[];
    final expenseCategories = shouldRefreshExpenseCategories
        ? await _getRowsIncludingGlobal('expense_categories')
        : const <Map<String, Object?>>[];
    final exchangeRates = shouldRefreshExchangeRates
        ? await _getRows('exchange_rates')
        : const <Map<String, Object?>>[];
    final cashRegisterSessions = shouldRefreshCashRegisterSessions
        ? await _getRows('cash_register_sessions')
        : const <Map<String, Object?>>[];
    final employees = shouldRefreshStaff
        ? await _getRows('employees')
        : const <Map<String, Object?>>[];
    final businessRules = shouldRefreshStaff
        ? await _getRows('business_rules')
        : const <Map<String, Object?>>[];
    final modifierIdsByProduct = shouldRefreshProducts
        ? _modifierIdsByProduct(productModifierGroups)
        : const <String, List<String>>{};

    await _database.transaction(() async {
      if (shouldRefreshBusinessSettings) {
        await _applyBusinessSettings(restaurantRows, invoiceSettings);
      }
      if (shouldRefreshAccessControl) {
        await _applyPermissions(permissions);
        await _applyRoles(roles);
        await _applyRolePermissions(rolePermissions, permissions, roles);
        await _applyUsers(profiles);
      }
      if (shouldRefreshCatalog) {
        await _applyCategories(categories);
      }
      if (shouldRefreshModifiers) {
        await _applyModifierGroups(modifierGroups);
        await _applyModifierOptions(modifierOptions);
      }
      if (shouldRefreshProducts) {
        await _applyProducts(products, modifierIdsByProduct);
        await _applyInventoryStock(inventoryStock);
      }
      if (shouldRefreshPackaging) {
        await _applySalesTypes(salesTypes);
        await _applyPackagingItems(packagingItems);
        await _applyProductPackagingRules(packagingRules);
        await _applyPackagingStock(packagingStock);
      }
      if (shouldRefreshPaymentMethods) {
        await _applyPaymentMethods(paymentMethods);
      }
      if (shouldRefreshTables) {
        await _applyTables(tables);
      }
      if (shouldRefreshExpenseCategories) {
        await _applyExpenseCategories(expenseCategories);
      }
      if (shouldRefreshExchangeRates) {
        await _applyExchangeRates(exchangeRates);
      }
      if (shouldRefreshCashRegisterSessions) {
        await _applyCashRegisterSessions(cashRegisterSessions);
      }
      if (shouldRefreshStaff) {
        await _applyEmployees(employees);
        await _applyBusinessRules(businessRules);
      }
    });

    return CatalogPullSummary(
      businessSettings: restaurantRows.isEmpty && invoiceSettings.isEmpty
          ? 0
          : 1,
      categories: categories.length,
      expenseCategories: expenseCategories.length,
      exchangeRates: exchangeRates.length,
      modifierGroups: modifierGroups.length,
      modifierOptions: modifierOptions.length,
      paymentMethods: paymentMethods.length,
      salesTypes: salesTypes.length,
      packagingItems: packagingItems.length,
      packagingRules: packagingRules.length,
      packagingStock: packagingStock.length,
      permissions: permissions.length,
      products: products.length,
      inventoryStock: inventoryStock.length,
      rolePermissions: rolePermissions.length,
      roles: roles.length,
      cashRegisterSessions: cashRegisterSessions.length,
      businessRules: businessRules.length,
      employees: employees.length,
      tables: tables.length,
      users: profiles.length,
    );
  }

}
