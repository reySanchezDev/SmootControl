import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/sales/data/models/sale_item_model.dart';
import 'package:smoo_control/features/sales/data/models/sale_model.dart';
import 'package:smoo_control/features/sales/data/models/sale_void_model.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';

/// Local datasource for sales and sale items.
final class LocalSalesDataSource {
  /// Creates a local sales datasource.
  const LocalSalesDataSource(this._database);

  final AppDatabase _database;

  /// Returns local sales created between two dates.
  Future<List<SaleModel>> getSales({
    required DateTime from,
    required DateTime to,
  }) async {
    final query = _database.select(_database.localSales)
      ..where((sale) => sale.createdAt.isBetweenValues(from, to))
      ..orderBy([(sale) => OrderingTerm.desc(sale.createdAt)]);
    final rows = await query.get();

    return _salesWithQueueStatus(rows);
  }

  /// Returns local sales for one cash register session.
  Future<List<SaleModel>> getSalesByCashRegisterSession(
    String sessionId,
  ) async {
    final query = _database.select(_database.localSales)
      ..where((sale) => sale.cashRegisterSessionId.equals(sessionId))
      ..orderBy([(sale) => OrderingTerm.desc(sale.createdAt)]);
    final rows = await query.get();

    return _salesWithQueueStatus(rows);
  }

  /// Returns local sale items for a sale.
  Future<List<SaleItemModel>> getSaleItems(String saleId) async {
    final query = _database.select(_database.localSaleItems)
      ..where((item) => item.saleId.equals(saleId))
      ..orderBy([(item) => OrderingTerm.asc(item.createdAt)]);
    final rows = await query.get();

    return rows.map(SaleItemModel.fromLocal).toList();
  }

  /// Returns local sale voids between two dates.
  Future<List<SaleVoidModel>> getSaleVoids({
    required DateTime from,
    required DateTime to,
  }) async {
    final query = _database.select(_database.localSaleVoids)
      ..where((voidRow) => voidRow.voidedAt.isBetweenValues(from, to))
      ..orderBy([(voidRow) => OrderingTerm.desc(voidRow.voidedAt)]);
    final rows = await query.get();

    return rows.map(SaleVoidModel.fromLocal).toList();
  }

  /// Saves a local sale and its details in one transaction.
  Future<SaleModel> saveSale({
    required SaleModel sale,
    required List<SaleItemModel> items,
  }) async {
    final now = DateTime.now();

    await _database.transaction(() async {
      await _database
          .into(_database.localSales)
          .insertOnConflictUpdate(
            LocalSalesCompanion(
              id: Value(sale.id),
              invoiceNumber: Value(sale.invoiceNumber),
              tableId: Value(sale.tableId),
              tableAccountId: Value(sale.tableAccountId),
              cashRegisterSessionId: Value(sale.cashRegisterSessionId),
              paymentMethodId: Value(sale.paymentMethodId),
              paymentReference: Value(sale.paymentReference),
              status: Value(sale.statusValue),
              subtotalInCents: Value(sale.subtotalInCents),
              totalInCents: Value(sale.totalInCents),
              syncStatus: Value(sale.syncStatusValue),
              createdAt: Value(sale.createdAt),
              updatedAt: Value(now),
            ),
          );

      for (final item in items) {
        await _database
            .into(_database.localSaleItems)
            .insertOnConflictUpdate(
              LocalSaleItemsCompanion(
                id: Value(item.id),
                saleId: Value(item.saleId),
                tableId: Value(item.tableId),
                tableAccountId: Value(item.tableAccountId),
                productId: Value(item.productId),
                productName: Value(item.productName),
                categoryName: Value(item.categoryName),
                selectedOptionsLabel: Value(item.selectedOptionsLabel),
                quantity: Value(item.quantity),
                unitPriceInCents: Value(item.unitPriceInCents),
                unitCostInCents: Value(item.unitCostInCents),
                createdAt: Value(item.createdAt),
                updatedAt: Value(now),
              ),
            );
      }
    });

    return sale;
  }

  /// Voids a local sale and records the audit row.
  Future<SaleModel> voidSale({
    required String saleId,
    required String reason,
    required String voidedBy,
  }) async {
    final now = DateTime.now();

    await _database.transaction(() async {
      await (_database.update(
        _database.localSales,
      )..where((sale) => sale.id.equals(saleId))).write(
        LocalSalesCompanion(
          status: const Value('voided'),
          updatedAt: Value(now),
        ),
      );

      await _database
          .into(_database.localSaleVoids)
          .insert(
            LocalSaleVoidsCompanion.insert(
              id: 'void-$saleId-${now.microsecondsSinceEpoch}',
              saleId: saleId,
              reason: reason,
              voidedBy: voidedBy,
              voidedAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    final row = await (_database.select(
      _database.localSales,
    )..where((sale) => sale.id.equals(saleId))).getSingle();

    return SaleModel.fromLocal(row);
  }

  Future<List<SaleModel>> _salesWithQueueStatus(List<LocalSale> rows) async {
    final sales = <SaleModel>[];
    for (final row in rows) {
      final model = SaleModel.fromLocal(row);
      sales.add(
        model.copyWith(
          syncStatus: await _latestQueueStatusForSale(
            row.id,
            fallback: model.syncStatus,
          ),
        ),
      );
    }

    return sales;
  }

  Future<SaleSyncStatus> _latestQueueStatusForSale(
    String saleId, {
    required SaleSyncStatus fallback,
  }) async {
    final row =
        await (_database.select(_database.localSyncQueue)
              ..where(
                (item) =>
                    item.entityType.equals('sales') &
                    item.entityId.equals(saleId),
              )
              ..orderBy([(item) => OrderingTerm.desc(item.updatedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return fallback;

    return SaleSyncStatus.values.firstWhere(
      (status) => status.name == row.status,
      orElse: () => SaleSyncStatus.pending,
    );
  }
}
