import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_expenses_repository.dart';

void main() {
  test('expires remote session when Supabase rejects unauthorized', () async {
    final remoteSession = CurrentRemoteSessionService()
      ..set(
        accessToken: 'expired-token',
        userId: 'admin',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
    addTearDown(remoteSession.dispose);

    final repository = SupabaseAdminExpensesRepository(
      client: MockClient(
        (_) async => http.Response('{"message":"JWT expired"}', 401),
      ),
      config: const SupabaseAppConfig(
        supabaseUrl: 'https://example.supabase.co',
        publishableKey: 'public-key',
      ),
      remoteSessionService: remoteSession,
      restaurantService: const CurrentRestaurantService(
        restaurantId: 'restaurant-1',
      ),
    );

    final result = await repository.getCategories();

    expect(result.isFailure, isTrue);
    expect(remoteSession.accessToken, isNull);
    expect(remoteSession.userId, isNull);
  });
}
