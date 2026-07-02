import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/sync/data/datasources/supabase_catalog_pull_service.dart';
import 'package:smoo_control/features/sync/domain/services/i_catalog_pull_service.dart';

void main() {
  group('SupabaseCatalogPullService', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('restores the operational POS dataset into an empty tablet', () async {
      final service = SupabaseCatalogPullService(
        database: database,
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://smoo.test',
          publishableKey: 'publishable-key',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: 'restaurant-1',
        ),
        remoteSessionService: _remoteSession(),
        client: _catalogMockClient(),
      );

      final summary = await service.pullOperationalCatalog();

      expect(summary.businessSettings, 1);
      expect(summary.permissions, 2);
      expect(summary.roles, 1);
      expect(summary.rolePermissions, 2);
      expect(summary.users, 1);
      expect(summary.categories, 1);
      expect(summary.modifierGroups, 1);
      expect(summary.modifierOptions, 1);
      expect(summary.products, 1);
      expect(summary.inventoryStock, 1);
      expect(summary.paymentMethods, 1);
      expect(summary.tables, 1);
      expect(summary.cashRegisterSessions, 1);
      expect(summary.expenseCategories, 1);
      expect(summary.exchangeRates, 1);
      expect(summary.isReadyForPos, isTrue);
      expect(summary.missingPosRequirements, isEmpty);

      final businessSettings = await database
          .select(database.localBusinessSettings)
          .getSingle();
      expect(businessSettings.businessName, 'Smoo Test');
      expect(businessSettings.invoicePrefix, 'F');
      expect(businessSettings.nextInvoiceNumber, 25);

      final users = await database.select(database.localUserProfiles).get();
      expect(users.single.email, 'pos@smoo.test');
      expect(users.single.isPosUser, isTrue);
      expect(users.single.pinHash, 'pin-hash');

      final rolePermissions = await database
          .select(database.localRolePermissions)
          .get();
      expect(
        rolePermissions.map((assignment) => assignment.permissionCode).toSet(),
        {'pos.acceder', 'ventas.crear'},
      );

      expect(
        await database.select(database.localProductCategories).get(),
        hasLength(1),
      );
      final products = await database.select(database.localProducts).get();
      expect(products, hasLength(1));
      expect(products.single.tracksInventory, isTrue);
      final stock = await database.select(database.localInventoryStock).get();
      expect(stock.single.quantityOnHand, 10);
      expect(
        await database.select(database.localModifierGroups).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.localModifierOptions).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.localRestaurantTables).get(),
        hasLength(1),
      );
      final cashSessions = await database
          .select(database.localCashRegisterSessions)
          .get();
      expect(cashSessions, hasLength(1));
      expect(cashSessions.single.cashierId, 'user-pos-1');
      expect(cashSessions.single.status, 'open');
      expect(
        await database.select(database.localPaymentMethods).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.localExpenseCategories).get(),
        hasLength(1),
      );

      final exchangeRates = await database
          .select(database.localExchangeRates)
          .get();
      expect(exchangeRates.single.currencyCode, 'USD');
      expect(exchangeRates.single.rateInCents, 3660);
    });

    test(
      'downloads with the current remote admin session without technical auth',
      () async {
        final remoteSession = CurrentRemoteSessionService()
          ..set(
            accessToken: 'owner-token',
            userId: 'owner-profile',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          );
        final requests = <http.Request>[];
        final service = SupabaseCatalogPullService(
          database: database,
          config: const SupabaseAppConfig(
            supabaseUrl: 'https://smoo.test',
            publishableKey: 'publishable-key',
          ),
          restaurantService: const CurrentRestaurantService(
            restaurantId: 'restaurant-1',
          ),
          remoteSessionService: remoteSession,
          client: MockClient((request) async {
            requests.add(request);
            if (request.url.path == '/auth/v1/token') {
              return http.Response('unexpected auth', 500);
            }
            final table = request.url.pathSegments.last;
            return _jsonResponse(_rowsByTable[table] ?? const <Object?>[]);
          }),
        );

        final summary = await service.pullOperationalCatalog();

        expect(summary.isReadyForPos, isTrue);
        expect(
          requests.every(
            (request) =>
                request.headers['authorization'] == 'Bearer owner-token',
          ),
          isTrue,
        );
        expect(
          requests.any((request) => request.url.path == '/auth/v1/token'),
          isFalse,
        );
      },
    );

    test(
      'reports missing operational data after an incomplete restore',
      () async {
        final service = SupabaseCatalogPullService(
          database: database,
          config: const SupabaseAppConfig(
            supabaseUrl: 'https://smoo.test',
            publishableKey: 'publishable-key',
          ),
          restaurantService: const CurrentRestaurantService(
            restaurantId: 'restaurant-1',
          ),
          remoteSessionService: _remoteSession(),
          client: _catalogMockClient(
            overrides: {
              'profiles': const <Map<String, Object?>>[],
              'products': const <Map<String, Object?>>[],
              'payment_methods': const <Map<String, Object?>>[],
            },
          ),
        );

        final summary = await service.pullOperationalCatalog();

        expect(summary.isReadyForPos, isFalse);
        expect(
          summary.missingPosRequirements,
          containsAll(['usuarios POS', 'productos', 'metodos de pago']),
        );
      },
    );
    test(
      'preserves pending local inventory deltas when stock is downloaded',
      () async {
        final now = DateTime(2026, 6, 30, 12);
        await database
            .into(database.localInventoryMovements)
            .insert(
              LocalInventoryMovementsCompanion.insert(
                id: 'sale-sale-local-product-chicken',
                productId: 'product-chicken',
                movementType: 'sale',
                quantityDelta: -2,
                referenceType: const Value('sale'),
                referenceId: const Value('sale-local'),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await database
            .into(database.localSyncQueue)
            .insert(
              LocalSyncQueueCompanion.insert(
                id: 'queue-sale-local',
                entityType: 'sales',
                entityId: 'sale-local',
                operation: 'create',
                payloadJson: '{}',
                status: const Value('pending'),
                createdAt: now,
                updatedAt: now,
              ),
            );
        final service = SupabaseCatalogPullService(
          database: database,
          config: const SupabaseAppConfig(
            supabaseUrl: 'https://smoo.test',
            publishableKey: 'publishable-key',
          ),
          restaurantService: const CurrentRestaurantService(
            restaurantId: 'restaurant-1',
          ),
          remoteSessionService: _remoteSession(),
          client: _catalogMockClient(),
        );

        await service.pullScopes({CatalogPullScope.products});

        final stock = await database
            .select(database.localInventoryStock)
            .getSingle();
        expect(stock.quantityOnHand, 8);
      },
    );

    test(
      'refreshes POS payment methods and expense categories from remote',
      () async {
        final now = DateTime(2026, 7);
        await database
            .into(database.localPaymentMethods)
            .insert(
              LocalPaymentMethodsCompanion.insert(
                id: 'payment-old',
                name: 'Pago viejo',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await database
            .into(database.localExpenseCategories)
            .insert(
              LocalExpenseCategoriesCompanion.insert(
                id: 'expense-old',
                name: 'Gasto viejo',
                createdAt: now,
                updatedAt: now,
              ),
            );
        final service = SupabaseCatalogPullService(
          database: database,
          config: const SupabaseAppConfig(
            supabaseUrl: 'https://smoo.test',
            publishableKey: 'publishable-key',
          ),
          restaurantService: const CurrentRestaurantService(
            restaurantId: 'restaurant-1',
          ),
          remoteSessionService: _remoteSession(),
          client: _catalogMockClient(
            overrides: {
              'payment_methods': [
                {
                  'id': 'payment-new',
                  'restaurant_id': 'restaurant-1',
                  'parent_id': null,
                  'name': 'Pago nuevo',
                  'group_name': 'Efectivo',
                  'currency_code': 'NIO',
                  'display_order': 1,
                  'is_payment_target': true,
                  'affects_cash': true,
                  'requires_reference': false,
                  'is_active': true,
                },
              ],
              'expense_categories': [
                {
                  'id': 'expense-new',
                  'restaurant_id': 'restaurant-1',
                  'parent_id': null,
                  'name': 'Gasto nuevo',
                  'is_active': true,
                },
              ],
            },
          ),
        );

        final summary = await service.pullScopes({
          CatalogPullScope.paymentMethods,
          CatalogPullScope.expenseCategories,
        });

        expect(summary.paymentMethods, 1);
        expect(summary.expenseCategories, 1);
        final paymentRows = await database
            .select(database.localPaymentMethods)
            .get();
        expect(
          paymentRows.singleWhere((row) => row.id == 'payment-old').isActive,
          isFalse,
        );
        expect(
          paymentRows.singleWhere((row) => row.id == 'payment-new').isActive,
          isTrue,
        );
        final expenseRows = await database
            .select(database.localExpenseCategories)
            .get();
        expect(
          expenseRows.singleWhere((row) => row.id == 'expense-old').isActive,
          isFalse,
        );
        expect(
          expenseRows.singleWhere((row) => row.id == 'expense-new').isActive,
          isTrue,
        );
      },
    );
  });
}

MockClient _catalogMockClient({
  Map<String, List<Map<String, Object?>>> overrides = const {},
}) {
  return MockClient((request) async {
    final table = request.url.pathSegments.last;
    return _jsonResponse(
      overrides.containsKey(table)
          ? overrides[table]!
          : _rowsByTable[table] ?? const <Object?>[],
    );
  });
}

CurrentRemoteSessionService _remoteSession() {
  return CurrentRemoteSessionService()..set(
    accessToken: 'owner-token',
    userId: 'owner-profile',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
}

http.Response _jsonResponse(Object value) {
  return http.Response(
    jsonEncode(value),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

final _rowsByTable = <String, List<Map<String, Object?>>>{
  'restaurants': [
    {
      'id': 'restaurant-1',
      'commercial_name': 'Smoo Test',
      'legal_name': 'Smoo Test LLC',
      'tax_identifier': 'J000000',
      'phone': '5555-5555',
      'address': 'Managua',
      'show_company_data_on_pdf': true,
    },
  ],
  'invoice_number_settings': [
    {
      'id': 'invoice-settings-1',
      'restaurant_id': 'restaurant-1',
      'prefix': 'F',
      'initial_number': 1,
      'next_number': 25,
    },
  ],
  'permissions': [
    {
      'id': 'permission-pos',
      'code': 'pos.acceder',
      'name': 'Acceder POS',
      'description': 'Permite operar el POS.',
    },
    {
      'id': 'permission-sales',
      'code': 'ventas.crear',
      'name': 'Crear ventas',
      'description': 'Permite crear ventas.',
    },
  ],
  'roles': [
    {
      'id': 'role-waiter',
      'restaurant_id': 'restaurant-1',
      'name': 'Mesero',
      'description': 'Operador POS',
      'is_system': false,
      'is_active': true,
    },
  ],
  'role_permissions': [
    {
      'role_id': 'role-waiter',
      'permission_id': 'permission-pos',
    },
    {
      'role_id': 'role-waiter',
      'permission_id': 'permission-sales',
    },
  ],
  'profiles': [
    {
      'id': 'user-pos-1',
      'restaurant_id': 'restaurant-1',
      'role_id': 'role-waiter',
      'display_name': 'Mesero POS',
      'email': 'pos@smoo.test',
      'pin_salt': 'pin-salt',
      'pin_hash': 'pin-hash',
      'is_pos_user': true,
      'is_active': true,
    },
  ],
  'product_categories': [
    {
      'id': 'category-food',
      'restaurant_id': 'restaurant-1',
      'parent_id': null,
      'name': 'Comidas',
      'display_order': 1,
      'is_active': true,
    },
  ],
  'modifier_groups': [
    {
      'id': 'modifier-group-sides',
      'restaurant_id': 'restaurant-1',
      'name': 'Guarniciones',
      'is_required': true,
      'display_order': 1,
      'is_active': true,
    },
  ],
  'modifier_options': [
    {
      'id': 'modifier-option-beans',
      'restaurant_id': 'restaurant-1',
      'group_id': 'modifier-group-sides',
      'name': 'Frijoles fritos',
      'price_delta': 0,
      'display_order': 1,
      'is_active': true,
      'is_available_in_pos': true,
    },
  ],
  'product_modifier_groups': [
    {
      'product_id': 'product-chicken',
      'modifier_group_id': 'modifier-group-sides',
      'display_order': 1,
    },
  ],
  'products': [
    {
      'id': 'product-chicken',
      'restaurant_id': 'restaurant-1',
      'category_id': 'category-food',
      'name': 'Pollo',
      'price': 180,
      'cost': 95,
      'is_active': true,
      'is_available_in_pos': true,
      'tracks_inventory': true,
      'option_groups': const [],
    },
  ],
  'inventory_stock': [
    {
      'restaurant_id': 'restaurant-1',
      'product_id': 'product-chicken',
      'quantity_on_hand': 10,
    },
  ],
  'payment_methods': [
    {
      'id': 'payment-cash',
      'restaurant_id': 'restaurant-1',
      'parent_id': null,
      'name': 'CORDOBA',
      'group_name': 'Efectivo',
      'currency_code': 'NIO',
      'display_order': 1,
      'is_payment_target': true,
      'affects_cash': true,
      'requires_reference': false,
      'is_active': true,
    },
  ],
  'restaurant_tables': [
    {
      'id': 'table-1',
      'restaurant_id': 'restaurant-1',
      'name': 'Mesa 1',
      'display_name': 'Mesa 1',
      'status': 'available',
      'is_active': true,
    },
  ],
  'cash_register_sessions': [
    {
      'id': 'cash-session-remote',
      'restaurant_id': 'restaurant-1',
      'cashier_user_id': 'user-pos-1',
      'business_date': '2026-06-30',
      'opening_cash_amount': 500,
      'counted_cash_amount': null,
      'status': 'open',
    },
  ],
  'expense_categories': [
    {
      'id': 'expense-category-admin',
      'restaurant_id': 'restaurant-1',
      'parent_id': null,
      'name': 'Administrativos',
      'is_active': true,
    },
  ],
  'exchange_rates': [
    {
      'restaurant_id': 'restaurant-1',
      'currency_code': 'USD',
      'business_date': '2026-06-30',
      'rate': 36.60,
    },
  ],
};
