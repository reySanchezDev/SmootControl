import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';
import 'package:smoo_control/features/products/presentation/pages/articles_page.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    CurrentOperatorService.currentSession = null;
  });
  tearDown(() async {
    CurrentOperatorService.currentSession = null;
    await serviceLocator.reset();
  });

  testWidgets('Products reads only canonical items including packaging', (
    tester,
  ) async {
    final client = _setUp(roleId: 'role-admin');
    await tester.pumpWidget(_app(const ArticlesPage()));
    await tester.pumpAndSettle();

    expect(find.text('Fruta laboratorio'), findsWidgets);
    expect(find.text('Bolsa laboratorio'), findsWidgets);
    expect(find.text('Empaque'), findsWidgets);
    expect(client.requestedTables, contains('items'));
    expect(client.requestedTables, isNot(contains('products')));
    expect(client.requestedTables, isNot(contains('packaging_items')));
  });

  testWidgets('packaging-only actor sees and creates only packaging items', (
    tester,
  ) async {
    final client = _setUp(roleId: 'role-packaging');
    await tester.pumpWidget(_app(const ArticlesPage()));
    await tester.pumpAndSettle();
    expect(find.text('Bolsa laboratorio'), findsWidgets);
    expect(find.text('Fruta laboratorio'), findsNothing);
    expect(find.text('Nuevo'), findsOneWidget);

    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo art\u00edculo'), findsOneWidget);
    expect(find.text('Producto'), findsNothing);
    expect(client.requestedTables, isNot(contains('products')));
    expect(client.requestedTables, isNot(contains('packaging_items')));
  });
}

MaterialApp _app(Widget home) => MaterialApp(
  home: home,
  locale: const Locale('es'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
);

_CatalogClient _setUp({required String roleId}) {
  final token = CurrentRemoteSessionService()
    ..set(accessToken: 'synthetic-jwt', userId: 'actor');
  const restaurant = CurrentRestaurantService(restaurantId: 'synthetic-tenant');
  final client = _CatalogClient();
  serviceLocator
    ..registerSingleton(const CurrentOperatorService())
    ..registerSingleton(token)
    ..registerSingleton(restaurant)
    ..registerSingleton(
      SupabaseAdminRepository(
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://local.test',
          publishableKey: 'synthetic-publishable',
        ),
        restaurantService: restaurant,
        remoteSessionService: token,
        client: client,
      ),
    );
  CurrentOperatorService.currentSession = AuthSession(
    userId: 'actor',
    email: 'lab@example.test',
    roleId: roleId,
    isPosUser: false,
  );
  return client;
}

class _CatalogClient extends http.BaseClient {
  final requestedTables = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final table = request.url.pathSegments.last;
    requestedTables.add(table);
    final rows = switch (table) {
      'products' => [
        {
          'id': 'fruit-1',
          'category_id': 'cat-1',
          'name': 'Fruta laboratorio',
          'cost': 0.5,
          'price': 3.5,
          'is_active': true,
          'is_available_in_pos': true,
          'is_raw_material': false,
          'uses_recipe': false,
          'tracks_inventory': true,
          'option_groups': <Object>[],
        },
      ],
      'items' => [
        {
          'id': 'fruit-1',
          'commercial_code': 1,
          'code': 'ART-1',
          'category_id': 'cat-1',
          'name': 'Fruta laboratorio',
          'item_type': 'inventory',
          'item_class': 'sale_product',
          'base_unit_id': 'unit-1',
          'base_unit_cost': 0.5,
          'base_unit_price': 3.5,
          'can_sell': true,
          'can_purchase': true,
          'visible_in_pos': true,
          'uses_recipe': false,
          'send_to_kitchen': false,
          'is_active': true,
        },
        {
          'id': 'pack-1',
          'commercial_code': 2,
          'code': 'ART-2',
          'category_id': null,
          'name': 'Bolsa laboratorio',
          'item_type': 'inventory',
          'item_class': 'packaging',
          'base_unit_id': 'unit-1',
          'base_unit_cost': 0.1,
          'base_unit_price': 0,
          'can_sell': false,
          'can_purchase': true,
          'visible_in_pos': false,
          'uses_recipe': false,
          'send_to_kitchen': false,
          'is_active': true,
        },
      ],
      'item_classification_links' => <Object>[],
      'item_classifications' => <Object>[],
      'product_categories' => [
        {
          'id': 'cat-1',
          'name': 'Laboratorio',
          'is_active': true,
          'display_order': 1,
        },
      ],
      'packaging_items' => [
        {
          'id': 'pack-1',
          'name': 'Bolsa laboratorio',
          'cost': 0.1,
          'tracks_stock': true,
          'is_active': true,
        },
      ],
      'role_permissions' => [
        {
          'permissions': {'code': 'empaques.gestionar'},
        },
      ],
      _ => <Map<String, Object?>>[],
    };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(rows))),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}
