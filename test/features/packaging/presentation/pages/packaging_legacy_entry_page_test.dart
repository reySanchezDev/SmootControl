import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/packaging/presentation/pages/packaging_legacy_entry_page.dart';

void main() {
  Future<void> pumpEntry(WidgetTester tester, Set<String> permissions) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PackagingLegacyEntryPage(
          permissionsLoader: () async => AppSuccess(permissions),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('full admin sees each independent destination', (tester) async {
    await pumpEntry(tester, {'tipos_venta.gestionar', 'empaques.gestionar'});

    expect(find.text('Modalidades de servicio'), findsOneWidget);
    expect(find.text('Empaques'), findsOneWidget);
    expect(find.text('Reglas de consumo'), findsOneWidget);
    expect(find.text('Tipos de venta'), findsNothing);
  });

  testWidgets('types-only profile cannot see packaging destinations', (
    tester,
  ) async {
    await pumpEntry(tester, {'tipos_venta.gestionar'});

    expect(find.text('Modalidades de servicio'), findsOneWidget);
    expect(find.text('Empaques'), findsNothing);
    expect(find.text('Reglas de consumo'), findsNothing);
  });

  testWidgets('packaging-only profile cannot see service modalities', (
    tester,
  ) async {
    await pumpEntry(tester, {'empaques.gestionar'});

    expect(find.text('Modalidades de servicio'), findsNothing);
    expect(find.text('Empaques'), findsOneWidget);
    expect(find.text('Reglas de consumo'), findsOneWidget);
  });

  testWidgets('empty permissions never mount an editor', (tester) async {
    await pumpEntry(tester, <String>{});

    expect(find.text('Acceso no autorizado'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
