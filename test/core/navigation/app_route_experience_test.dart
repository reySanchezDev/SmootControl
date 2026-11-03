import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/navigation/app_route_experience.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';

void main() {
  const pos = AuthSession(
    userId: 'pos',
    email: 'pos@example.test',
    roleId: 'operator',
    isPosUser: true,
  );
  const admin = AuthSession(
    userId: 'admin',
    email: 'admin@example.test',
    roleId: 'administrator',
    isPosUser: false,
  );

  test('Routes are classified independently of viewport', () {
    expect(AppRouteExperience.forRoute(AppRoutes.pos), SmooExperience.pos);
    expect(
      AppRouteExperience.forRoute(AppRoutes.products),
      SmooExperience.backoffice,
    );
    expect(
      AppRouteExperience.forRoute(AppRoutes.dashboard),
      SmooExperience.backoffice,
    );
    expect(AppRouteExperience.forRoute('/unknown'), isNull);
  });

  test('POS session may not enter Backoffice routes', () {
    expect(AppRouteExperience.allows(pos, AppRoutes.pos), isTrue);
    expect(AppRouteExperience.allows(pos, AppRoutes.dashboard), isFalse);
    expect(AppRouteExperience.allows(pos, AppRoutes.users), isFalse);
    expect(AppRouteExperience.allows(pos, '/unknown'), isFalse);
  });

  test('Backoffice session may not enter POS routes', () {
    expect(AppRouteExperience.allows(admin, AppRoutes.products), isTrue);
    expect(AppRouteExperience.allows(admin, AppRoutes.pos), isFalse);
    expect(AppRouteExperience.allows(admin, '/unknown'), isFalse);
  });
}
