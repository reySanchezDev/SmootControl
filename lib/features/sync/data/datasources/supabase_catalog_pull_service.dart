import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
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
    required http.Client client,
  }) : _database = database,
       _config = config,
       _restaurantService = restaurantService,
       _client = client;

  final AppDatabase _database;
  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final http.Client _client;

  String? _accessToken;
  DateTime? _expiresAt;

  @override
  Future<CatalogPullSummary> pullOperationalCatalog() {
    return pullScopes(CatalogPullScope.values.toSet());
  }

  @override
  Future<CatalogPullSummary> pullScopes(Set<CatalogPullScope> scopes) async {
    _ensureConfigured();

    if (scopes.isEmpty) return const CatalogPullSummary.empty();

    final effectiveScopes = {...scopes};
    if (effectiveScopes.contains(CatalogPullScope.products)) {
      effectiveScopes
        ..add(CatalogPullScope.catalog)
        ..add(CatalogPullScope.modifiers);
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
      permissions: permissions.length,
      products: products.length,
      inventoryStock: inventoryStock.length,
      rolePermissions: rolePermissions.length,
      roles: roles.length,
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
    for (final row in rows) {
      final productId = _optionalText(row['product_id']);
      if (productId == null) continue;
      await _database
          .into(_database.localInventoryStock)
          .insert(
            LocalInventoryStockCompanion(
              productId: Value(productId),
              quantityOnHand: Value(_int(row['quantity_on_hand'])),
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

  void _ensureConfigured() {
    if (!_config.isConfigured || !_restaurantService.isConfigured) {
      throw StateError(
        'Supabase remoto no esta configurado para descargar datos.',
      );
    }
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
        'No se pudo autenticar Supabase para descargar datos '
        '(${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw StateError('Respuesta de autenticacion Supabase invalida.');
    }

    final accessToken = decoded['access_token'];
    final expiresIn = decoded['expires_in'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw StateError('Supabase no devolvio access_token.');
    }

    _accessToken = accessToken;
    _expiresAt = DateTime.now().add(
      Duration(seconds: expiresIn is int ? expiresIn : 3600),
    );
    return accessToken;
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
