import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/inventory/data/services/supabase_inventory_movements_service.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_movement_document.dart';

void main() {
  test(
    'loads sale movement detail using its document identity fields',
    () async {
      final service = SupabaseInventoryMovementsService(
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://smoo.test',
          publishableKey: 'publishable-key',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: 'restaurant-1',
        ),
        remoteSessionService: _remoteSession(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/items')) {
            return http.Response(
              jsonEncode([
                {'id': 'item-10', 'name': 'MARUCHAN'},
              ]),
              200,
            );
          }
          return http.Response(
            jsonEncode([
              {
                'id': 'movement-1',
                'item_id': 'item-10',
                'quantity_delta': '-4',
                'unit_cost': '37',
                'movement_type': 'sale',
                'reference_type': 'sale',
                'reference_id': 'sale-1322',
              },
            ]),
            200,
          );
        }),
      );

      final result = await service.loadLines(
        InventoryMovementDocument(
          id: 'sale|sale|sale-1322',
          type: InventoryMovementDocumentType.sale,
          title: 'Venta',
          createdAt: DateTime(2026, 11, 18, 8, 15),
          lineCount: 1,
          quantityDelta: -4,
        ),
      );

      expect(result, isA<AppSuccess<List<InventoryMovementDocumentLine>>>());
      final lines =
          (result as AppSuccess<List<InventoryMovementDocumentLine>>).value;
      expect(lines.single.productName, 'MARUCHAN');
      expect(lines.single.quantityDelta, -4);
      expect(lines.single.unitCostInCents, 3700);
    },
  );
}

CurrentRemoteSessionService _remoteSession() =>
    CurrentRemoteSessionService()..set(
      accessToken: 'access-token',
      userId: 'remote-admin',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
