import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/navigation/app_router.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';

void main() {
  test('obsolete preview bookmark resolves to real authenticated entry', () {
    final route = onGenerateAppRoute(
      const RouteSettings(name: '/backoffice-v2-preview'),
    );

    expect(route, isA<MaterialPageRoute<void>>());
    expect(route.settings.name, AppRoutes.dashboard);
  });

  test('operational routes remain unchanged', () {
    final route = onGenerateAppRoute(
      const RouteSettings(name: AppRoutes.products),
    );

    expect(route.settings.name, AppRoutes.products);
  });
}
