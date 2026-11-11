import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/app_run_mode.dart';
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/navigation/route_access.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

const _requiredPermission = 'productos.gestionar';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    CurrentOperatorService.currentSession = null;
  });

  tearDown(() async {
    CurrentOperatorService.currentSession = null;
    await serviceLocator.reset();
  });

  testWidgets('admin role keeps the route available', (tester) async {
    if (!AppRunMode.isBackoffice) return;
    await _pumpGuard(tester, roleId: DefaultAccessRoles.adminId);

    expect(find.text('contenido protegido'), findsOneWidget);
  });

  testWidgets('partial remote permission grants only its route', (
    tester,
  ) async {
    if (!AppRunMode.isBackoffice) return;
    await _pumpGuard(tester, permissions: [_requiredPermission]);

    expect(find.text('contenido protegido'), findsOneWidget);
  });

  testWidgets('missing remote permission denies the route', (tester) async {
    if (!AppRunMode.isBackoffice) return;
    await _pumpGuard(tester, permissions: const []);

    expect(find.text('contenido protegido'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('remote permission read failure denies the route', (
    tester,
  ) async {
    if (!AppRunMode.isBackoffice) return;
    await _pumpGuard(tester, statusCode: 503);

    expect(find.text('contenido protegido'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}

Future<void> _pumpGuard(
  WidgetTester tester, {
  String roleId = 'role-manager',
  List<String> permissions = const [],
  int statusCode = 200,
}) async {
  final remoteSession = CurrentRemoteSessionService()
    ..set(accessToken: 'test-token', userId: 'test-user');
  serviceLocator
    ..registerSingleton(const CurrentOperatorService())
    ..registerSingleton(remoteSession)
    ..registerSingleton(
      const CurrentRestaurantService(restaurantId: 'test-restaurant'),
    );
  serviceLocator.registerSingleton(
    SupabaseAdminRepository(
      config: const SupabaseAppConfig(
        supabaseUrl: 'https://local.test',
        publishableKey: 'test-key',
      ),
      restaurantService: serviceLocator<CurrentRestaurantService>(),
      remoteSessionService: remoteSession,
      client: _PermissionClient(statusCode, permissions),
    ),
  );
  CurrentOperatorService.currentSession = AuthSession(
    userId: 'test-user',
    email: 'admin@local.test',
    roleId: roleId,
    isPosUser: false,
  );

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RouteAccessGuard(
        anyPermissions: [_requiredPermission],
        child: Text('contenido protegido'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _PermissionClient extends http.BaseClient {
  _PermissionClient(this.statusCode, this.permissions);

  final int statusCode;
  final List<String> permissions;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = jsonEncode([
      for (final permission in permissions)
        <String, Object?>{
          'permissions': <String, Object?>{'code': permission},
        },
    ]);
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}
