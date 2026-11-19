import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/presentation/widgets/sync_queue_tile.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('shows business labels without local technical ids', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SyncQueueTile(
            item: SyncQueueItem(
              id: 'queue-1',
              entityType: 'sales',
              entityId: 'sale-technical-id',
              operation: SyncOperation.create,
              payload: const {},
              status: SyncQueueStatus.pending,
              retryCount: 0,
              createdAt: DateTime(2026, 6, 24, 10, 30),
              updatedAt: DateTime(2026, 6, 24, 10, 30),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sales'), findsOneWidget);
    expect(find.textContaining('New record'), findsOneWidget);
    expect(find.textContaining('Pending'), findsOneWidget);
    expect(find.textContaining('sale-technical-id'), findsNothing);
    expect(find.text('sales'), findsNothing);
    expect(find.text('pending'), findsNothing);
  });

  testWidgets('labels stale catalog operations as requiring resolution', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SyncQueueTile(
            item: SyncQueueItem(
              id: 'queue-stale',
              entityType: 'sales',
              entityId: 'sale-1',
              operation: SyncOperation.create,
              payload: const {},
              status: SyncQueueStatus.requiresResolution,
              retryCount: 1,
              lastError: 'Venta retenida por versión obsoleta.',
              createdAt: DateTime(2026, 11, 18),
              updatedAt: DateTime(2026, 11, 18),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Requiere conciliación'), findsOneWidget);
    expect(find.textContaining('versión obsoleta'), findsOneWidget);
  });
}
