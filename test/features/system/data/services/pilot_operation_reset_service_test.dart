import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/system/data/services/pilot_operation_reset_service.dart';

void main() {
  group('PilotOperationResetService', () {
    late AppDatabase database;
    late CurrentRemoteSessionService sessionService;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      sessionService = CurrentRemoteSessionService()
        ..set(
          accessToken: 'remote-token',
          userId: 'admin-user',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
    });

    tearDown(() async {
      await database.close();
    });

    test('clears operational data and keeps catalogs/settings base', () async {
      final now = DateTime(2026, 7);
      await _seedLocalData(database, now);

      final service = PilotOperationResetService(
        database: database,
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://example.supabase.co',
          publishableKey: 'public-key',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: '11111111-1111-4111-8111-111111111111',
        ),
        remoteSessionService: sessionService,
        client: _FakeClient((request) async {
          expect(
            request.url.toString(),
            'https://example.supabase.co/rest/v1/rpc/reset_pilot_operation',
          );
          expect(request.headers['authorization'], 'Bearer remote-token');
          final body = jsonDecode(await request.finalize().bytesToString());
          expect(
            body,
            containsPair(
              'p_confirmation',
              PilotOperationResetService.confirmationText,
            ),
          );
          return http.Response(
            jsonEncode({'total_rows': 9}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await service.resetPilotOperation(
        confirmation: PilotOperationResetService.confirmationText,
      );

      expect(result, isA<AppSuccess<PilotOperationResetSummary>>());
      final summary = (result as AppSuccess<PilotOperationResetSummary>).value;
      expect(summary.remoteRows, 9);
      expect(summary.localRows, 6);

      expect(await _count(database, 'local_sales'), 0);
      expect(await _count(database, 'local_sale_items'), 0);
      expect(await _count(database, 'local_cash_register_sessions'), 0);
      expect(await _count(database, 'local_sync_queue'), 0);
      expect(await _count(database, 'local_product_categories'), 1);

      final inventoryStock = await database
          .select(database.localInventoryStock)
          .getSingle();
      expect(inventoryStock.quantityOnHand, 0);
      expect(inventoryStock.syncStatus, 'synced');

      final packagingStock = await database
          .select(database.localPackagingStock)
          .getSingle();
      expect(packagingStock.quantityOnHand, 0);
      expect(packagingStock.syncStatus, 'synced');

      final table = await database
          .select(database.localRestaurantTables)
          .getSingle();
      expect(table.status, 'available');
      expect(table.displayName, isNull);

      final settings = await database
          .select(database.localBusinessSettings)
          .getSingle();
      expect(settings.nextInvoiceNumber, settings.initialInvoiceNumber);
    });
  });
}

Future<void> _seedLocalData(AppDatabase database, DateTime now) async {
  await database
      .into(database.localProductCategories)
      .insert(
        LocalProductCategoriesCompanion.insert(
          id: 'category-1',
          name: 'Comidas',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localBusinessSettings)
      .insert(
        LocalBusinessSettingsCompanion.insert(
          id: 'settings',
          businessName: 'Smoo',
          createdAt: now,
          updatedAt: now,
          initialInvoiceNumber: const Value(100),
          nextInvoiceNumber: const Value(108),
        ),
      );
  await database
      .into(database.localRestaurantTables)
      .insert(
        LocalRestaurantTablesCompanion.insert(
          id: 'table-1',
          name: 'Mesa 1',
          displayName: const Value('Cliente A'),
          status: const Value('occupied'),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localInventoryStock)
      .insert(
        LocalInventoryStockCompanion.insert(
          productId: 'product-1',
          quantityOnHand: const Value(12),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localPackagingStock)
      .insert(
        LocalPackagingStockCompanion.insert(
          packagingItemId: 'packaging-1',
          quantityOnHand: const Value(7),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localCashRegisterSessions)
      .insert(
        LocalCashRegisterSessionsCompanion.insert(
          id: 'cash-1',
          cashierId: 'user-1',
          businessDate: '2026-07-01',
          openingCashInCents: 10000,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localSales)
      .insert(
        LocalSalesCompanion.insert(
          id: 'sale-1',
          invoiceNumber: 'F-1',
          paymentMethodId: 'payment-1',
          cashRegisterSessionId: const Value('cash-1'),
          subtotalInCents: 18000,
          totalInCents: 18000,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localSaleItems)
      .insert(
        LocalSaleItemsCompanion.insert(
          id: 'sale-item-1',
          saleId: const Value('sale-1'),
          productId: 'product-1',
          productName: 'Pollo',
          categoryName: 'Comidas',
          quantity: 1,
          unitPriceInCents: 18000,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localInventoryMovements)
      .insert(
        LocalInventoryMovementsCompanion.insert(
          id: 'inventory-movement-1',
          productId: 'product-1',
          movementType: 'sale',
          quantityDelta: -1,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localPackagingMovements)
      .insert(
        LocalPackagingMovementsCompanion.insert(
          id: 'packaging-movement-1',
          packagingItemId: 'packaging-1',
          movementType: 'packaging_sale',
          quantityDelta: -1,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localSyncQueue)
      .insert(
        LocalSyncQueueCompanion.insert(
          id: 'sync-1',
          entityType: 'sale',
          entityId: 'sale-1',
          operation: 'create',
          payloadJson: '{}',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<int> _count(AppDatabase database, String tableName) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS row_count FROM $tableName')
      .getSingle();
  return row.data['row_count'] as int;
}

final class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}
