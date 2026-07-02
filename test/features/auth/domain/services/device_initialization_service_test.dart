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
import 'package:smoo_control/features/auth/data/services/remote_bootstrap_auth_service.dart';
import 'package:smoo_control/features/auth/domain/services/device_initialization_service.dart';
import 'package:smoo_control/features/auth/domain/services/remote_bootstrap_session.dart';
import 'package:smoo_control/features/sync/data/datasources/supabase_catalog_pull_service.dart';

void main() {
  group('DeviceInitializationService', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'requests remote initialization for a clean Supabase device',
      () async {
        final service = _service(
          database: database,
          config: const SupabaseAppConfig(
            supabaseUrl: 'https://smoo.test',
            publishableKey: 'publishable-key',
          ),
          restaurantService: const CurrentRestaurantService(
            restaurantId: 'restaurant-1',
          ),
        );

        final result = await service.getStartupMode();

        expect(
          result.when(success: (value) => value, failure: (_) => null),
          DeviceStartupMode.remoteInitialization,
        );
      },
    );

    test('allows local setup when Supabase is not configured', () async {
      final service = _service(
        database: database,
        config: const SupabaseAppConfig(),
        restaurantService: const CurrentRestaurantService(),
      );

      final result = await service.getStartupMode();

      expect(
        result.when(success: (value) => value, failure: (_) => null),
        DeviceStartupMode.localInitialSetup,
      );
    });

    test('uses local PIN login when a local user already exists', () async {
      final now = DateTime(2026, 6, 30, 10);
      await database
          .into(database.localUserProfiles)
          .insert(
            LocalUserProfilesCompanion.insert(
              id: 'user-1',
              displayName: 'Admin',
              email: 'admin@smoo.test',
              roleId: 'role-admin',
              pinSalt: const Value('salt'),
              pinHash: const Value('hash'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final service = _service(
        database: database,
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://smoo.test',
          publishableKey: 'publishable-key',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: 'restaurant-1',
        ),
      );

      final result = await service.getStartupMode();

      expect(
        result.when(success: (value) => value, failure: (_) => null),
        DeviceStartupMode.localLogin,
      );
    });

    test('forces remote initialization after a failed restore', () async {
      final now = DateTime(2026, 6, 30, 10);
      await database
          .into(database.localUserProfiles)
          .insert(
            LocalUserProfilesCompanion.insert(
              id: 'user-1',
              displayName: 'Admin',
              email: 'admin@smoo.test',
              roleId: 'role-admin',
              pinSalt: const Value('salt'),
              pinHash: const Value('hash'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.localDeviceState)
          .insert(
            LocalDeviceStateCompanion.insert(
              deviceId: 'device-1',
              restaurantId: 'restaurant-1',
              initializedByUserId: 'user-1',
              initializedAt: now,
              lastFullRestoreAt: now,
              lastRestoreStatus: 'failed',
              lastRestoreError: const Value('missing catalog'),
            ),
          );
      final service = _service(
        database: database,
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://smoo.test',
          publishableKey: 'publishable-key',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: 'restaurant-1',
        ),
      );

      final result = await service.getStartupMode();

      expect(
        result.when(success: (value) => value, failure: (_) => null),
        DeviceStartupMode.remoteInitialization,
      );
    });

    test('restores a clean system even before catalog is loaded', () async {
      final service = _service(
        database: database,
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://smoo.test',
          publishableKey: 'publishable-key',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: 'restaurant-1',
        ),
        client: _restoreClient(),
      );

      final result = await service.restoreDevice(
        session: RemoteBootstrapSession(
          accessToken: 'admin-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime(2026, 7),
          userId: 'user-1',
          email: 'admin@smoo.test',
          displayName: 'Admin',
          roleId: 'role-admin',
          restaurantId: 'restaurant-1',
          hasLocalPin: true,
        ),
      );

      expect(result.isSuccess, isTrue);
      final state = await database.select(database.localDeviceState).get();
      expect(state.single.lastRestoreStatus, 'completed');
    });
  });
}

DeviceInitializationService _service({
  required AppDatabase database,
  required SupabaseAppConfig config,
  required CurrentRestaurantService restaurantService,
  MockClient? client,
}) {
  final effectiveClient =
      client ??
      MockClient((request) async {
        return http.Response('[]', 200);
      });

  return DeviceInitializationService(
    database: database,
    config: config,
    restaurantService: restaurantService,
    remoteAuthService: RemoteBootstrapAuthService(
      config: config,
      restaurantService: restaurantService,
      remoteSessionService: CurrentRemoteSessionService(),
      client: effectiveClient,
    ),
    catalogPullService: SupabaseCatalogPullService(
      database: database,
      config: config,
      restaurantService: restaurantService,
      remoteSessionService: CurrentRemoteSessionService(),
      client: effectiveClient,
    ),
  );
}

MockClient _restoreClient() {
  return MockClient((request) async {
    final table = request.url.pathSegments.last;
    final rows = switch (table) {
      'restaurants' => [
        {
          'id': 'restaurant-1',
          'commercial_name': 'Smoo Test',
          'show_company_data_on_pdf': true,
        },
      ],
      'invoice_number_settings' => [
        {
          'restaurant_id': 'restaurant-1',
          'prefix': 'F',
          'initial_number': 1,
          'next_number': 1,
        },
      ],
      'permissions' => [
        {
          'id': 'permission-sales',
          'code': 'ventas.registrar',
          'name': 'Ventas',
        },
      ],
      'roles' => [
        {
          'id': 'role-admin',
          'code': 'admin',
          'name': 'Administrador',
          'is_system': true,
          'is_active': true,
        },
      ],
      'role_permissions' => [
        {'role_id': 'role-admin', 'permission_id': 'permission-sales'},
      ],
      'profiles' => [
        {
          'id': 'user-1',
          'display_name': 'Admin',
          'email': 'admin@smoo.test',
          'role_id': 'role-admin',
          'pin_salt': 'salt',
          'pin_hash': 'hash',
          'is_pos_user': false,
          'is_active': true,
        },
      ],
      _ => const <Map<String, Object?>>[],
    };

    return http.Response(
      jsonEncode(rows),
      200,
      headers: const {'content-type': 'application/json'},
    );
  });
}
