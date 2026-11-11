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

void main() {
  setUp(() async {
    await serviceLocator.reset();
    CurrentOperatorService.currentSession = null;
  });
  tearDown(() async {
    CurrentOperatorService.currentSession = null;
    await serviceLocator.reset();
  });

  testWidgets('one articles catalog includes product and packaging', (
    tester,
  ) async {
    _setUp(roleId: 'role-admin');
    await tester.pumpWidget(const MaterialApp(home: ArticlesPage()));
    await tester.pumpAndSettle();

    expect(find.text('Fruta laboratorio'), findsWidgets);
    expect(find.text('Bolsa laboratorio'), findsWidgets);
    expect(find.text('Producto de venta'), findsWidgets);
    expect(find.text('Empaque'), findsWidgets);

    await tester.tap(find.text('Todos').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empaques').last);
    await tester.pumpAndSettle();

    expect(find.text('Bolsa laboratorio'), findsWidgets);
    expect(find.text('Fruta laboratorio'), findsNothing);
  });

  testWidgets('packaging-only actor sees no product and cannot create it', (
    tester,
  ) async {
    _setUp(roleId: 'role-packaging');
    await tester.pumpWidget(const MaterialApp(home: ArticlesPage()));
    await tester.pumpAndSettle();
    expect(find.text('Bolsa laboratorio'), findsWidgets);
    expect(find.text('Fruta laboratorio'), findsNothing);
    expect(find.text('Nuevo empaque'), findsOneWidget);
    expect(find.text('Nuevo producto'), findsNothing);
  });
}

void _setUp({required String roleId}) {
  final token = CurrentRemoteSessionService()
    ..set(accessToken: 'synthetic-jwt', userId: 'actor');
  const restaurant = CurrentRestaurantService(restaurantId: 'synthetic-tenant');
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
        client: _CatalogClient(),
      ),
    );
  CurrentOperatorService.currentSession = AuthSession(
    userId: 'actor',
    email: 'lab@example.test',
    roleId: roleId,
    isPosUser: false,
  );
}

class _CatalogClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final table = request.url.pathSegments.last;
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
