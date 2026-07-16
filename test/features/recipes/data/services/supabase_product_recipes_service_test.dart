import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/recipes/data/services/supabase_product_recipes_service.dart';
import 'package:smoo_control/features/recipes/domain/entities/product_recipe.dart';

void main() {
  group('SupabaseProductRecipesService', () {
    test('loads active recipe with ingredient labels', () async {
      final service = _service(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/product_recipes')) {
            return http.Response(
              jsonEncode([
                {'id': 'recipe-1', 'product_id': 'burger', 'version': 2},
              ]),
              200,
            );
          }
          return http.Response(
            jsonEncode([
              {
                'component_product_id': 'bread',
                'quantity': 1,
                'unit_id': 'unit',
                'waste_percent': 0,
                'display_order': 0,
                'products': {'name': 'Pan hamburguesa'},
                'measurement_units': {'name': 'Unidad', 'code': 'unit'},
              },
            ]),
            200,
          );
        }),
      );

      final result = await service.loadActiveRecipe('burger');

      expect(result, isA<AppSuccess<ProductRecipe?>>());
      final recipe = (result as AppSuccess<ProductRecipe?>).value!;
      expect(recipe.id, 'recipe-1');
      expect(recipe.lines.single.componentName, 'Pan hamburguesa');
      expect(recipe.lines.single.unitName, 'Unidad (unit)');
    });

    test('saves recipe through the remote RPC', () async {
      final requests = <http.Request>[];
      final service = _service(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'line_count': 1}), 200);
        }),
      );

      final result = await service.saveRecipe(
        productId: 'burger',
        lines: const [
          ProductRecipeLine(
            componentProductId: 'bread',
            quantity: 1,
            unitId: 'unit',
          ),
        ],
      );

      expect(result, isA<AppSuccess<void>>());
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/app_save_product_recipe',
      );
      final body = jsonDecode(requests.single.body) as Map<String, Object?>;
      expect(body['p_restaurant_id'], 'restaurant-1');
      expect(body['p_product_id'], 'burger');
      final lines = body['p_lines']! as List<Object?>;
      expect(lines.single, containsPair('component_product_id', 'bread'));
      expect(lines.single, containsPair('quantity', 1));
      expect(lines.single, containsPair('unit_id', 'unit'));
    });
  });
}

SupabaseProductRecipesService _service({required http.Client client}) {
  return SupabaseProductRecipesService(
    config: const SupabaseAppConfig(
      supabaseUrl: 'https://smoo.test',
      publishableKey: 'publishable-key',
    ),
    restaurantService: const CurrentRestaurantService(
      restaurantId: 'restaurant-1',
    ),
    remoteSessionService: _remoteSession(),
    client: client,
  );
}

CurrentRemoteSessionService _remoteSession() {
  return CurrentRemoteSessionService()..set(
    accessToken: 'token',
    userId: 'admin-user',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
}
