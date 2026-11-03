import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/attendance/presentation/pages/time_clock_gate.dart';
import 'package:smoo_control/features/auth/domain/services/device_initialization_service.dart';

void main() {
  testWidgets('Time Clock displays loading while startup mode is pending', (
    tester,
  ) async {
    final pending = Completer<AppResult<DeviceStartupMode>>();

    await tester.pumpWidget(
      MaterialApp(
        home: TimeClockGate(startupModeLoader: () => pending.future),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Marcador'), findsNothing);

    pending.complete(
      const AppFailureResult<DeviceStartupMode>(
        AppFailure(
          code: 'time_clock_test_unavailable',
          message: 'Sin conexión de prueba.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Marcador'), findsOneWidget);
    expect(find.text('Sin conexión de prueba.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Time Clock shows startup errors without opening POS', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TimeClockGate(
          startupModeLoader: () async =>
              const AppFailureResult<DeviceStartupMode>(
                AppFailure(
                  code: 'time_clock_test_failed',
                  message: 'No se pudo validar el marcador.',
                ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Marcador'), findsOneWidget);
    expect(find.text('No se pudo validar el marcador.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('local login opens standalone Time Clock and not POS', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TimeClockGate(
          startupModeLoader: () async =>
              const AppSuccess(DeviceStartupMode.localLogin),
          timeClockPageBuilder: (_) => const Text('Marcador independiente'),
          initializationPageBuilder: (_, _) =>
              const Text('Inicialización de dispositivo'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Marcador independiente'), findsOneWidget);
    expect(find.text('Inicialización de dispositivo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('initialization reload transitions to standalone marker', (
    tester,
  ) async {
    var initialized = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TimeClockGate(
          startupModeLoader: () async => AppSuccess(
            initialized
                ? DeviceStartupMode.localLogin
                : DeviceStartupMode.remoteInitialization,
          ),
          timeClockPageBuilder: (_) => const Text('Marcador independiente'),
          initializationPageBuilder: (_, reload) => TextButton(
            onPressed: () {
              initialized = true;
              reload();
            },
            child: const Text('Restaurar dispositivo'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Restaurar dispositivo'), findsOneWidget);
    await tester.tap(find.text('Restaurar dispositivo'));
    await tester.pumpAndSettle();

    expect(find.text('Marcador independiente'), findsOneWidget);
    expect(find.text('Restaurar dispositivo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

}
