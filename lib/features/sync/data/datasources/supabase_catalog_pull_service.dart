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
        ? await _getRows('products')
        : const <Map<String, Object?>>[];
    final inventoryStock = shouldRefreshProducts
        ? await _getRows('inventory_stock')
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
      tables: tables.length,
      users: profiles.length,
    );
  }

  Future<void> _applyBusinessSettings(
    List<Map<String, Object?>> restaurantRows,
    List<Map<String, Object?>> invoiceRows,
  ) async {
    if (restaurantRows.isEmpty && invoiceRows.isEmpty) return;

    final now = DateTime.now();
    final existing = await (_database.select(
      _database.localBusinessSettings,
    )..where((settings) => settings.id.equals('default'))).getSingleOrNull();
    final restaurant = restaurantRows.isEmpty ? null : restaurantRows.first;
    final invoice = invoiceRows.isEmpty ? null : invoiceRows.first;

    await _database
        .into(_database.localBusinessSettings)
        .insert(
          LocalBusinessSettingsCompanion(
            id: const Value('default'),
            businessName: Value(
              _optionalText(restaurant?['commercial_name']) ??
                  existing?.businessName ??
                  'SmooControl',
            ),
            legalName: Value(
              _optionalText(restaurant?['legal_name']) ?? existing?.legalName,
            ),
            taxNumber: Value(
              _optionalText(restaurant?['tax_identifier']) ??
                  existing?.taxNumber,
            ),
            phone: Value(
              _optionalText(restaurant?['phone']) ?? existing?.phone,
            ),
            address: Value(
              _optionalText(restaurant?['address']) ?? existing?.address,
            ),
            showCompanyInfoOnReceipts: Value(
              restaurant == null
                  ? existing?.showCompanyInfoOnReceipts ?? true
                  : _bool(
                      restaurant['show_company_data_on_pdf'],
                      defaultValue: true,
                    ),
            ),
            invoicePrefix: Value(
              _optionalText(invoice?['prefix']) ??
                  existing?.invoicePrefix ??
                  'F',
            ),
            initialInvoiceNumber: Value(
              _int(invoice?['initial_number'], defaultValue: 1),
            ),
            nextInvoiceNumber: Value(
              _int(invoice?['next_number'], defaultValue: 1),
            ),
            remoteId: Value(_restaurantService.restaurantId),
            syncStatus: const Value('synced'),
            syncError: const Value(null),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
            syncedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> _applyPermissions(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    for (final row in rows) {
      final code = _optionalText(row['code']);
      if (code == null) continue;
      await _database
          .into(_database.localPermissions)
          .insert(
            LocalPermissionsCompanion(
              code: Value(code),
              name: Value(_text(row['name'], defaultValue: code)),
              description: Value(_optionalText(row['description'])),
              remoteId: Value(_optionalText(row['id'])),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  Future<void> _applyRoles(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'roles');
      await _database
          .into(_database.localRoles)
          .insert(
            LocalRolesCompanion(
              id: Value(id),
              name: Value(_text(row['name'], defaultValue: 'Rol')),
              description: Value(_optionalText(row['description'])),
              isSystem: Value(_bool(row['is_system'])),
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
  }

  Future<void> _applyRolePermissions(
    List<Map<String, Object?>> rows,
    List<Map<String, Object?>> permissions,
    List<Map<String, Object?>> roles,
  ) async {
    final permissionCodeById = <String, String>{};
    for (final permission in permissions) {
      final id = _optionalText(permission['id']);
      final code = _optionalText(permission['code']);
      if (id != null && code != null) permissionCodeById[id] = code;
    }

    final remoteRoleIds = roles
        .map((role) => _optionalText(role['id']))
        .whereType<String>()
        .toSet();
    if (remoteRoleIds.isEmpty) return;

    final now = DateTime.now();
    await _database.batch((batch) {
      for (final roleId in remoteRoleIds) {
        batch.deleteWhere(
          _database.localRolePermissions,
          (assignment) => assignment.roleId.equals(roleId),
        );
      }
      for (final row in rows) {
        final roleId = _optionalText(row['role_id']);
        final permissionId = _optionalText(row['permission_id']);
        final permissionCode = permissionCodeById[permissionId];
        if (roleId == null ||
            permissionCode == null ||
            !remoteRoleIds.contains(roleId)) {
          continue;
        }
        batch.insert(
          _database.localRolePermissions,
          LocalRolePermissionsCompanion(
            id: Value('$roleId:$permissionCode'),
            roleId: Value(roleId),
            permissionCode: Value(permissionCode),
            remoteId: Value('$roleId:$permissionCode'),
            syncStatus: const Value('synced'),
            syncError: const Value(null),
            createdAt: Value(now),
            updatedAt: Value(now),
            syncedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> _applyUsers(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'profiles');
      final existing = await (_database.select(
        _database.localUserProfiles,
      )..where((user) => user.id.equals(id))).getSingleOrNull();
      final roleId = _optionalText(row['role_id']) ?? existing?.roleId;
      if (roleId == null) continue;

      await _database
          .into(_database.localUserProfiles)
          .insert(
            LocalUserProfilesCompanion(
              id: Value(id),
              displayName: Value(
                _text(row['display_name'], defaultValue: 'Usuario'),
              ),
              email: Value(_text(row['email'], defaultValue: '')),
              roleId: Value(roleId),
              pinSalt: Value(
                _optionalText(row['pin_salt']) ?? existing?.pinSalt,
              ),
              pinHash: Value(
                _optionalText(row['pin_hash']) ?? existing?.pinHash,
              ),
              isPosUser: Value(
                _bool(
                  row['is_pos_user'],
                  defaultValue: existing?.isPosUser ?? false,
                ),
              ),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

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
                _bool(row['is_available_in_pos'], defaultValue: true),
              ),
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

  Future<void> _applyInventoryStock(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final pendingDeltas = await _pendingInventoryDeltasByProduct();
    for (final row in rows) {
      final productId = _optionalText(row['product_id']);
      if (productId == null) continue;
      final remoteQuantity = _int(row['quantity_on_hand']);
      final localPendingDelta = pendingDeltas[productId] ?? 0;
      final adjustedQuantity = remoteQuantity + localPendingDelta;
      if (adjustedQuantity < 0) {
        throw StateError(
          'La descarga de inventario produciria stock negativo para '
          '$productId por movimientos locales pendientes.',
        );
      }
      await _database
          .into(_database.localInventoryStock)
          .insert(
            LocalInventoryStockCompanion(
              productId: Value(productId),
              quantityOnHand: Value(adjustedQuantity),
              remoteId: Value(productId),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  Future<void> _applySalesTypes(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'sales_types');
      remoteIds.add(id);
      await _database
          .into(_database.localSalesTypes)
          .insert(
            LocalSalesTypesCompanion(
              id: Value(id),
              code: Value(_text(row['code'], defaultValue: id)),
              name: Value(_text(row['name'], defaultValue: 'Tipo de venta')),
              displayOrder: Value(_int(row['display_order'])),
              isDefault: Value(_bool(row['is_default'])),
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
    await _markMissingSalesTypesInactive(remoteIds, now);
  }

  Future<void> _applyPackagingItems(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'packaging_items');
      remoteIds.add(id);
      await _database
          .into(_database.localPackagingItems)
          .insert(
            LocalPackagingItemsCompanion(
              id: Value(id),
              name: Value(_text(row['name'], defaultValue: 'Empaque')),
              costInCents: Value(_moneyCents(row['cost'])),
              tracksStock: Value(
                _bool(row['tracks_stock'], defaultValue: true),
              ),
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
    await _markMissingPackagingItemsInactive(remoteIds, now);
  }

  Future<void> _applyProductPackagingRules(
    List<Map<String, Object?>> rows,
  ) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'product_packaging_rules');
      final productId = _optionalText(row['product_id']);
      final salesTypeId = _optionalText(row['sales_type_id']);
      final packagingItemId = _optionalText(row['packaging_item_id']);
      if (productId == null || salesTypeId == null || packagingItemId == null) {
        continue;
      }
      remoteIds.add(id);
      await _database
          .into(_database.localProductPackagingRules)
          .insert(
            LocalProductPackagingRulesCompanion(
              id: Value(id),
              productId: Value(productId),
              salesTypeId: Value(salesTypeId),
              packagingItemId: Value(packagingItemId),
              quantityPerUnit: Value(
                _int(row['quantity_per_unit'], defaultValue: 1),
              ),
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
    await _markMissingPackagingRulesInactive(remoteIds, now);
  }

  Future<void> _applyPackagingStock(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final pendingDeltas = await _pendingPackagingDeltasByItem();
    for (final row in rows) {
      final packagingItemId = _optionalText(row['packaging_item_id']);
      if (packagingItemId == null) continue;
      final remoteQuantity = _int(row['quantity_on_hand']);
      final adjustedQuantity =
          remoteQuantity + (pendingDeltas[packagingItemId] ?? 0);
      if (adjustedQuantity < 0) {
        throw StateError(
          'La descarga de empaques produciria stock negativo para '
          '$packagingItemId por movimientos locales pendientes.',
        );
      }
      await _database
          .into(_database.localPackagingStock)
          .insert(
            LocalPackagingStockCompanion(
              packagingItemId: Value(packagingItemId),
              quantityOnHand: Value(adjustedQuantity),
              remoteId: Value(packagingItemId),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  Future<Map<String, int>> _pendingInventoryDeltasByProduct() async {
    final movements = await _database
        .select(_database.localInventoryMovements)
        .get();
    if (movements.isEmpty) return const {};

    final salesQueue = await (_database.select(
      _database.localSyncQueue,
    )..where((item) => item.entityType.equals('sales'))).get();
    final inventoryQueue = await (_database.select(
      _database.localSyncQueue,
    )..where((item) => item.entityType.equals('inventory_movements'))).get();
    final salesByEntity = _latestQueueByEntityId(salesQueue);
    final inventoryByEntity = _latestQueueByEntityId(inventoryQueue);

    final deltas = <String, int>{};
    for (final movement in movements) {
      if (!_shouldPreserveMovementDelta(
        movement,
        salesByEntity: salesByEntity,
        inventoryByEntity: inventoryByEntity,
      )) {
        continue;
      }
      deltas.update(
        movement.productId,
        (value) => value + movement.quantityDelta,
        ifAbsent: () => movement.quantityDelta,
      );
    }
    return deltas;
  }

  Future<Map<String, int>> _pendingPackagingDeltasByItem() async {
    final movements = await _database
        .select(_database.localPackagingMovements)
        .get();
    if (movements.isEmpty) return const {};

    final salesQueue = await (_database.select(
      _database.localSyncQueue,
    )..where((item) => item.entityType.equals('sales'))).get();
    final packagingQueue = await (_database.select(
      _database.localSyncQueue,
    )..where((item) => item.entityType.equals('packaging_movements'))).get();
    final salesByEntity = _latestQueueByEntityId(salesQueue);
    final packagingByEntity = _latestQueueByEntityId(packagingQueue);

    final deltas = <String, int>{};
    for (final movement in movements) {
      if (!_shouldPreservePackagingMovementDelta(
        movement,
        salesByEntity: salesByEntity,
        packagingByEntity: packagingByEntity,
      )) {
        continue;
      }
      deltas.update(
        movement.packagingItemId,
        (value) => value + movement.quantityDelta,
        ifAbsent: () => movement.quantityDelta,
      );
    }
    return deltas;
  }

  Map<String, LocalSyncQueueData> _latestQueueByEntityId(
    List<LocalSyncQueueData> rows,
  ) {
    final byEntityId = <String, LocalSyncQueueData>{};
    for (final row in rows) {
      final current = byEntityId[row.entityId];
      if (current == null || row.updatedAt.isAfter(current.updatedAt)) {
        byEntityId[row.entityId] = row;
      }
    }
    return byEntityId;
  }

  bool _shouldPreserveMovementDelta(
    LocalInventoryMovement movement, {
    required Map<String, LocalSyncQueueData> salesByEntity,
    required Map<String, LocalSyncQueueData> inventoryByEntity,
  }) {
    final referenceType = movement.referenceType;
    if (referenceType == 'sale' || referenceType == 'sale_void') {
      final referenceId = movement.referenceId;
      if (referenceId == null) return true;
      return _isNotSynced(salesByEntity[referenceId], missingIsPending: true);
    }

    if (referenceType == 'purchase') {
      return _isNotSynced(
        inventoryByEntity[movement.id],
        missingIsPending: false,
      );
    }

    return false;
  }

  bool _shouldPreservePackagingMovementDelta(
    LocalPackagingMovement movement, {
    required Map<String, LocalSyncQueueData> salesByEntity,
    required Map<String, LocalSyncQueueData> packagingByEntity,
  }) {
    final referenceType = movement.referenceType;
    if (referenceType == 'sale' || referenceType == 'sale_void') {
      final referenceId = movement.referenceId;
      if (referenceId == null) return true;
      return _isNotSynced(salesByEntity[referenceId], missingIsPending: true);
    }

    if (referenceType == 'packaging_purchase') {
      return _isNotSynced(
        packagingByEntity[movement.id],
        missingIsPending: false,
      );
    }

    return false;
  }

  bool _isNotSynced(
    LocalSyncQueueData? row, {
    required bool missingIsPending,
  }) {
    if (row == null) return missingIsPending;
    return row.status != 'synced';
  }

  Future<void> _applyPaymentMethods(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'payment_methods');
      remoteIds.add(id);
      await _database
          .into(_database.localPaymentMethods)
          .insert(
            LocalPaymentMethodsCompanion(
              id: Value(id),
              name: Value(_text(row['name'], defaultValue: 'Metodo')),
              parentId: Value(_optionalText(row['parent_id'])),
              groupName: Value(_text(row['group_name'], defaultValue: 'Otros')),
              currencyCode: Value(_optionalText(row['currency_code'])),
              displayOrder: Value(_int(row['display_order'])),
              isPaymentTarget: Value(
                _bool(row['is_payment_target'], defaultValue: true),
              ),
              affectsCashRegister: Value(
                _bool(row['affects_cash']),
              ),
              requiresReference: Value(_bool(row['requires_reference'])),
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
    await _markMissingPaymentMethodsInactive(remoteIds, now);
  }

  Future<void> _applyTables(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'restaurant_tables');
      final existing = await (_database.select(
        _database.localRestaurantTables,
      )..where((table) => table.id.equals(id))).getSingleOrNull();
      remoteIds.add(id);
      await _database
          .into(_database.localRestaurantTables)
          .insert(
            LocalRestaurantTablesCompanion(
              id: Value(id),
              name: Value(_text(row['name'], defaultValue: 'Mesa')),
              displayName: Value(
                existing?.displayName ?? _optionalText(row['display_name']),
              ),
              status: Value(
                existing?.status ??
                    _text(row['status'], defaultValue: 'available'),
              ),
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
    await _markMissingTablesInactive(remoteIds, now);
  }

  Future<void> _applyExpenseCategories(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'expense_categories');
      remoteIds.add(id);
      await _database
          .into(_database.localExpenseCategories)
          .insert(
            LocalExpenseCategoriesCompanion(
              id: Value(id),
              name: Value(_text(row['name'], defaultValue: 'Gasto')),
              parentId: Value(_optionalText(row['parent_id'])),
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
    await _markMissingExpenseCategoriesInactive(remoteIds, now);
  }

  Future<void> _applyExchangeRates(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    for (final row in rows) {
      final currencyCode = _optionalText(row['currency_code']);
      final businessDate = _date(row['business_date']);
      if (currencyCode == null || businessDate == null) continue;
      await _database
          .into(_database.localExchangeRates)
          .insert(
            LocalExchangeRatesCompanion(
              currencyCode: Value(currencyCode),
              businessDate: Value(businessDate),
              rateInCents: Value(_moneyCents(row['rate'])),
              remoteId: Value('$currencyCode-${_dateKey(businessDate)}'),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  Future<void> _applyCashRegisterSessions(
    List<Map<String, Object?>> rows,
  ) async {
    final now = DateTime.now();
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'cash_register_sessions');
      final cashierId = _optionalText(row['cashier_user_id']);
      final businessDate = _date(row['business_date']);
      if (cashierId == null || businessDate == null) continue;

      final existing = await (_database.select(
        _database.localCashRegisterSessions,
      )..where((session) => session.id.equals(id))).getSingleOrNull();

      await _database
          .into(_database.localCashRegisterSessions)
          .insert(
            LocalCashRegisterSessionsCompanion(
              id: Value(id),
              cashierId: Value(cashierId),
              businessDate: Value(BusinessDateFormatter.format(businessDate)),
              openingCashInCents: Value(
                _moneyCents(row['opening_cash_amount']),
              ),
              physicalClosingCashInCents: Value(
                row['counted_cash_amount'] == null
                    ? null
                    : _moneyCents(row['counted_cash_amount']),
              ),
              status: Value(_text(row['status'], defaultValue: 'open')),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  Future<void> _markMissingCategoriesInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(
          _database.localProductCategories,
        )
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localProductCategories,
      )..where((category) => category.id.equals(row.id))).write(
        LocalProductCategoriesCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingProductsInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database.select(_database.localProducts).get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) ||
          (!row.isActive && !row.isAvailableInPos)) {
        continue;
      }
      final hasOpenTicket = await _hasOpenTicketForProduct(row.id);
      await (_database.update(
        _database.localProducts,
      )..where((product) => product.id.equals(row.id))).write(
        LocalProductsCompanion(
          isActive: Value(hasOpenTicket),
          isAvailableInPos: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingModifierGroupsInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(
          _database.localModifierGroups,
        )
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localModifierGroups,
      )..where((group) => group.id.equals(row.id))).write(
        LocalModifierGroupsCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingModifierOptionsInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(
          _database.localModifierOptions,
        )
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) ||
          (!row.isActive && !row.isAvailableInPos)) {
        continue;
      }
      await (_database.update(
        _database.localModifierOptions,
      )..where((option) => option.id.equals(row.id))).write(
        LocalModifierOptionsCompanion(
          isActive: const Value(false),
          isAvailableInPos: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingSalesTypesInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database.select(_database.localSalesTypes).get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localSalesTypes,
      )..where((type) => type.id.equals(row.id))).write(
        LocalSalesTypesCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingPackagingItemsInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(_database.localPackagingItems)
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localPackagingItems,
      )..where((item) => item.id.equals(row.id))).write(
        LocalPackagingItemsCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingPackagingRulesInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(_database.localProductPackagingRules)
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localProductPackagingRules,
      )..where((rule) => rule.id.equals(row.id))).write(
        LocalProductPackagingRulesCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingPaymentMethodsInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(
          _database.localPaymentMethods,
        )
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localPaymentMethods,
      )..where((method) => method.id.equals(row.id))).write(
        LocalPaymentMethodsCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingTablesInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(
          _database.localRestaurantTables,
        )
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      if (await _hasOpenTicketForTable(row.id)) continue;
      await (_database.update(
        _database.localRestaurantTables,
      )..where((table) => table.id.equals(row.id))).write(
        LocalRestaurantTablesCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingExpenseCategoriesInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(
          _database.localExpenseCategories,
        )
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localExpenseCategories,
      )..where((category) => category.id.equals(row.id))).write(
        LocalExpenseCategoriesCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<bool> _hasOpenTicketForProduct(String productId) async {
    final row = await (_database.select(
      _database.localPosOpenTicketLines,
    )..where((line) => line.productId.equals(productId))).getSingleOrNull();
    return row != null;
  }

  Future<bool> _hasOpenTicketForTable(String tableId) async {
    final row = await (_database.select(
      _database.localPosOpenTicketLines,
    )..where((line) => line.tableId.equals(tableId))).getSingleOrNull();
    return row != null;
  }

  Future<List<Map<String, Object?>>> _getRows(
    String table, {
    String select = '*',
  }) async {
    return _getRowsByQuery(table, {
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'select': select,
    });
  }

  Future<List<Map<String, Object?>>> _getRowsIncludingGlobal(
    String table, {
    String select = '*',
  }) async {
    final restaurantId = _restaurantService.restaurantId;
    return _getRowsByQuery(table, {
      'or': '(restaurant_id.is.null,restaurant_id.eq.$restaurantId)',
      'select': select,
    });
  }

  Future<List<Map<String, Object?>>> _getGlobalRows(
    String table, {
    String select = '*',
  }) async {
    return _getRowsByQuery(table, {
      'restaurant_id': 'is.null',
      'select': select,
    });
  }

  Future<List<Map<String, Object?>>> _getRowsByQuery(
    String table,
    Map<String, String> query,
  ) async {
    final deviceRows = _deviceCatalogRows;
    if (deviceRows != null) {
      return _rowsFromDeviceCatalog(deviceRows, table, query);
    }

    final response = await _client.get(
      _config.restUri(table, query),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Supabase rechazo descarga de $table (${response.statusCode}): '
        '${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw StateError('Respuesta invalida descargando $table.');
    }

    return decoded.map(_mapRow).toList();
  }

  Future<void> _prepareDeviceCatalogIfNeeded() async {
    if (_hasRemoteCatalogToken) return;
    _deviceCatalogRows = await _pullOperationalCatalogWithDevice();
  }

  Future<Map<String, List<Map<String, Object?>>>>
  _pullOperationalCatalogWithDevice() async {
    final credentials = await _deviceCredentials();
    final response = await _client.post(
      _config.rpcUri('pos_pull_operational_catalog'),
      headers: {
        'apikey': _config.publishableKey,
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({
        'p_restaurant_id': _restaurantService.restaurantId,
        'p_device_id': credentials.deviceId,
        'p_device_secret': credentials.deviceSecret,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Supabase rechazo descarga POS (${response.statusCode}): '
        '${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw StateError('Respuesta invalida descargando catalogo POS.');
    }

    return decoded.map((key, value) {
      final rows = value is List
          ? value.map(_mapRow).toList(growable: false)
          : <Map<String, Object?>>[];
      return MapEntry(key.toString(), rows);
    });
  }

  List<Map<String, Object?>> _rowsFromDeviceCatalog(
    Map<String, List<Map<String, Object?>>> snapshot,
    String table,
    Map<String, String> query,
  ) {
    Iterable<Map<String, Object?>> rows = snapshot[table] ?? const [];

    for (final entry in query.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == 'select' || key == 'limit') continue;
      if (key == 'or') {
        rows = _applyDeviceOrFilter(rows, value);
        continue;
      }
      rows = _applyDeviceFilter(rows, key, value);
    }

    final limit = int.tryParse(query['limit'] ?? '');
    if (limit != null && limit >= 0) rows = rows.take(limit);
    return rows.toList();
  }

  Iterable<Map<String, Object?>> _applyDeviceFilter(
    Iterable<Map<String, Object?>> rows,
    String key,
    String expression,
  ) {
    if (expression.startsWith('eq.')) {
      final expected = expression.substring(3);
      return rows.where((row) => _optionalText(row[key]) == expected);
    }
    if (expression == 'is.null') {
      return rows.where((row) => _optionalText(row[key]) == null);
    }
    return rows;
  }

  Iterable<Map<String, Object?>> _applyDeviceOrFilter(
    Iterable<Map<String, Object?>> rows,
    String expression,
  ) {
    final normalized = expression.trim();
    if (!normalized.startsWith('(') || !normalized.endsWith(')')) {
      return rows;
    }
    final clauses = normalized
        .substring(1, normalized.length - 1)
        .split(',')
        .map((clause) => clause.trim())
        .where((clause) => clause.isNotEmpty)
        .toList();
    if (clauses.isEmpty) return rows;

    return rows.where((row) {
      for (final clause in clauses) {
        final isNullParts = clause.split('.is.');
        if (isNullParts.length == 2 && isNullParts[1] == 'null') {
          if (_optionalText(row[isNullParts[0]]) == null) return true;
          continue;
        }

        final eqParts = clause.split('.eq.');
        if (eqParts.length == 2 &&
            _optionalText(row[eqParts[0]]) == eqParts[1]) {
          return true;
        }
      }
      return false;
    });
  }

  Future<void> _ensureDefaultSalesTypes() async {
    final response = await _client.post(
      _config.restUri('rpc/ensure_default_sales_types'),
      headers: {
        ...await _headers(),
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'p_restaurant_id': _restaurantService.restaurantId,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Supabase rechazo creacion de tipos de venta base '
        '(${response.statusCode}): ${response.body}',
      );
    }
  }

  Map<String, List<String>> _modifierIdsByProduct(
    List<Map<String, Object?>> rows,
  ) {
    final grouped = <String, List<_ProductModifierLink>>{};
    for (final row in rows) {
      final productId = _optionalText(row['product_id']);
      final groupId = _optionalText(row['modifier_group_id']);
      if (productId == null || groupId == null) continue;
      grouped
          .putIfAbsent(productId, () => [])
          .add(_ProductModifierLink(groupId, _int(row['display_order'])));
    }

    return grouped.map((productId, links) {
      links.sort((first, second) => first.order.compareTo(second.order));
      return MapEntry(productId, links.map((link) => link.groupId).toList());
    });
  }

  Future<void> _ensureCanPull() async {
    if (!_config.isConfigured || !_restaurantService.isConfigured) {
      throw StateError('Supabase no esta configurado para descargar datos.');
    }
    if (_hasRemoteCatalogToken || await _hasDeviceCredentials()) return;
    throw StateError(
      'Inicializa este dispositivo o inicia sesion como administrador remoto '
      'para descargar datos.',
    );
  }

  bool get _hasRemoteCatalogToken {
    return (_accessToken != null && _accessToken!.isNotEmpty) ||
        _remoteSessionService.hasUsableToken;
  }

  Future<Map<String, String>> _headers() async {
    return {
      'apikey': _config.publishableKey,
      'authorization': 'Bearer ${await _authToken()}',
      'accept': 'application/json',
    };
  }

  Future<String> _authToken() async {
    final token = _accessToken;
    final expiration = _expiresAt;
    if (token != null &&
        expiration != null &&
        expiration.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      return token;
    }

    if (_temporaryTokenOnly) {
      throw StateError(
        'La sesion remota de inicializacion expiro. Inicia sesion nuevamente.',
      );
    }

    final sessionToken = _remoteSessionService.accessToken;
    if (sessionToken != null) return sessionToken;

    throw StateError(
      'La sesion remota expiro. Inicia sesion como administrador remoto.',
    );
  }

  Future<_DeviceCatalogCredentials> _deviceCredentials() async {
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
    return _DeviceCatalogCredentials(
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

  Map<String, Object?> _mapRow(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  String _requiredText(Object? value, {required String table}) {
    final text = _optionalText(value);
    if (text == null) {
      throw StateError('Fila remota de $table sin id valido.');
    }
    return text;
  }

  String _text(Object? value, {required String defaultValue}) {
    return _optionalText(value) ?? defaultValue;
  }

  String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  bool _bool(Object? value, {bool defaultValue = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return defaultValue;
  }

  int _int(Object? value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  int _moneyCents(Object? value) {
    if (value is int) return value * 100;
    if (value is num) return (value * 100).round();
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return (parsed * 100).round();
    }
    return 0;
  }

  DateTime? _date(Object? value) {
    final text = _optionalText(value);
    if (text == null) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _jsonListText(Object? value) {
    if (value is String) return value;
    if (value is List) return jsonEncode(value);
    return '[]';
  }
}

final class _ProductModifierLink {
  const _ProductModifierLink(this.groupId, this.order);

  final String groupId;
  final int order;
}

final class _DeviceCatalogCredentials {
  const _DeviceCatalogCredentials({
    required this.deviceId,
    required this.deviceSecret,
  });

  final String deviceId;
  final String deviceSecret;
}
