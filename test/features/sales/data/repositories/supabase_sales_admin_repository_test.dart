import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/sales/data/repositories/supabase_sales_admin_repository.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';

void main() {
  group('SupabaseSalesAdminRepository', () {
    test('loads sales from Supabase for the selected business date', () async {
      final requests = <http.Request>[];
      final repository = SupabaseSalesAdminRepository(
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://smoo.test',
          publishableKey: 'publishable-key',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: 'restaurant-1',
        ),
        remoteSessionService: _remoteSession(),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([
              {
                'id': 'sale-remote-1',
                'invoice_number': 'F-18',
                'table_id': null,
                'table_account_id': null,
                'cash_register_session_id': 'cash-1',
                'payment_method_id': 'cash-cordoba',
                'payment_reference': null,
                'sales_type_id': 'to-go-id',
                'sales_type_name': 'Para llevar',
                'status': 'completed',
                'sync_status': 'synced',
                'total_amount': '1980.0000',
                'sold_at': '2026-07-01T22:26:03.092Z',
                'created_at': '2026-07-02T04:26:02.211Z',
              },
            ]),
            200,
          );
        }),
      );

      final result = await repository.getSales(
        from: DateTime(2026, 7),
        to: DateTime(2026, 7, 2),
      );

      expect(result, isA<AppSuccess<List<Sale>>>());
      final sales = (result as AppSuccess<List<Sale>>).value;
      expect(sales.single.invoiceNumber, 'F-18');
      expect(sales.single.totalInCents, 198000);
      expect(sales.single.salesTypeName, 'Para llevar');
      expect(sales.single.syncStatus, SaleSyncStatus.synced);
      expect(requests.single.url.path, '/rest/v1/sales');
      expect(
        requests.single.url.queryParameters['restaurant_id'],
        'eq.restaurant-1',
      );
      expect(
        requests.single.url.queryParameters['and'],
        contains('sold_at.gte.'),
      );
    });

    test('loads sale items from Supabase for a selected sale', () async {
      final requests = <http.Request>[];
      final repository = SupabaseSalesAdminRepository(
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://smoo.test',
          publishableKey: 'publishable-key',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: 'restaurant-1',
        ),
        remoteSessionService: _remoteSession(),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([
              {
                'id': 'item-1',
                'sale_id': 'sale-remote-1',
                'table_id': 'table-1',
                'table_account_id': null,
                'product_id': 'product-1',
                'product_code': 'P001',
                'product_name': 'POLLO',
                'category_name': 'COMIDAS',
                'selected_options_label':
                    'BASTIMENTO: MADURO - GUARNICION: FRIJOLES',
                'quantity': 2,
                'unit_price': '180.0000',
                'unit_cost': '90.0000',
                'created_at': '2026-07-01T22:26:03.092Z',
              },
            ]),
            200,
          );
        }),
      );

      final result = await repository.getSaleItems('sale-remote-1');

      expect(result, isA<AppSuccess<List<SaleItem>>>());
      final items = (result as AppSuccess<List<SaleItem>>).value;
      expect(items.single.productName, 'POLLO');
      expect(items.single.quantity, 2);
      expect(items.single.unitPriceInCents, 18000);
      expect(items.single.selectedOptionsLabel, contains('BASTIMENTO'));
      expect(requests.single.url.path, '/rest/v1/sale_items');
      expect(
        requests.single.url.queryParameters['sale_id'],
        'eq.sale-remote-1',
      );
      expect(
        requests.single.url.queryParameters['order'],
        'created_at.asc',
      );
    });
  });
}

CurrentRemoteSessionService _remoteSession() {
  return CurrentRemoteSessionService()..set(
    accessToken: 'access-token',
    userId: 'remote-admin',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
}
