import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/presentation/widgets/audit_log_tile.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('shows user-facing labels instead of technical audit keys', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AuditLogTile(
            entry: AuditLogEntry(
              id: 'audit-1',
              action: 'sales.void',
              entityName: 'sales',
              entityId: 'sale-1',
              details: const {'reason': 'Error de captura'},
              occurredAt: DateTime(2026, 6, 24, 10, 30),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sale voided'), findsOneWidget);
    expect(find.textContaining('Reason: Error de captura'), findsOneWidget);
    expect(find.text('sales.void'), findsNothing);
    expect(find.textContaining('reason:'), findsNothing);
  });
}
