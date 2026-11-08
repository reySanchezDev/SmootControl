import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/navigation/app_route_experience.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/core/navigation/route_access.dart';

void main() {
  test('scoped packaging destinations stay in Backoffice', () {
    for (final route in [
      AppRoutes.salesTypes,
      AppRoutes.packagingItems,
      AppRoutes.packagingRules,
    ]) {
      expect(AppRouteExperience.forRoute(route), SmooExperience.backoffice);
    }
    expect(
      AppRouteExperience.forRoute(AppRoutes.packaging),
      SmooExperience.backoffice,
    );
  });

  test('Products is a virtual article catalog for products and packaging', () {
    expect(
      RouteAccess.anyPermissionsFor(AppRoutes.products),
      containsAll(['productos.gestionar', 'empaques.gestionar']),
    );
    expect(RouteAccess.anyPermissionsFor(AppRoutes.packagingItems), [
      'empaques.gestionar',
    ]);
    expect(RouteAccess.anyPermissionsFor(AppRoutes.packagingRules), [
      'empaques.gestionar',
    ]);
  });

  test('service modalities cannot navigate with packaging-only permission', () {
    expect(RouteAccess.anyPermissionsFor(AppRoutes.salesTypes), [
      'tipos_venta.gestionar',
    ]);
  });

  test('packaging catalogs cannot navigate with types-only permission', () {
    expect(RouteAccess.anyPermissionsFor(AppRoutes.packagingItems), [
      'empaques.gestionar',
    ]);
    expect(RouteAccess.anyPermissionsFor(AppRoutes.packagingRules), [
      'empaques.gestionar',
    ]);
  });

  test('legacy path remains known during compatibility transition', () {
    expect(
      RouteAccess.anyPermissionsFor(AppRoutes.packaging),
      containsAll(['empaques.gestionar', 'tipos_venta.gestionar']),
    );
  });
}
