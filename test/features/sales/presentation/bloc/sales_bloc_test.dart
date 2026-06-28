import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:smoo_control/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:smoo_control/features/sales/presentation/bloc/sales_event.dart';
import 'package:smoo_control/features/sales/presentation/bloc/sales_state.dart';

void main() {
  group('SalesBloc', () {
    final sale = Sale(
      id: 'sale-1',
      invoiceNumber: 'F-0001',
      paymentMethodId: 'cash',
      status: SaleStatus.completed,
      subtotalInCents: 500,
      totalInCents: 500,
      createdAt: DateTime(2026, 6, 23),
    );
    final item = SaleItem(
      id: 'item-1',
      saleId: 'sale-1',
      productId: 'product-1',
      productName: 'Sopa',
      categoryName: 'Sopa',
      quantity: 1,
      unitPriceInCents: 500,
      unitCostInCents: 200,
      createdAt: DateTime(2026, 6, 23),
    );

    blocTest<SalesBloc, SalesState>(
      'loads sales',
      build: () => SalesBloc(
        repository: _SalesRepositoryFake(salesResult: AppSuccess([sale])),
        auditLogRepository: AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(
        SalesLoadRequested(
          from: DateTime(2026, 6, 23),
          to: DateTime(2026, 6, 24),
        ),
      ),
      expect: () => [
        const SalesLoading(),
        SalesLoaded([sale]),
      ],
    );

    blocTest<SalesBloc, SalesState>(
      'loads sale items',
      build: () => SalesBloc(
        repository: _SalesRepositoryFake(itemsResult: AppSuccess([item])),
        auditLogRepository: AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(const SaleItemsLoadRequested('sale-1')),
      expect: () => [
        const SalesLoading(),
        SaleItemsLoaded(saleId: 'sale-1', items: [item]),
      ],
    );

    blocTest<SalesBloc, SalesState>(
      'voids sale and writes audit log',
      setUp: () {
        audit = AuditLogRepositoryFake();
      },
      build: () => SalesBloc(
        repository: _SalesRepositoryFake(voidResult: AppSuccess(sale)),
        auditLogRepository: audit,
      ),
      act: (bloc) => bloc.add(
        const SaleVoided(
          saleId: 'sale-1',
          reason: 'Error',
          voidedBy: 'admin-1',
        ),
      ),
      expect: () => [
        const SalesLoading(),
        SaleVoidSuccess(sale),
      ],
      verify: (_) {
        expect(audit.entries.single.action, 'sales.void');
        expect(audit.entries.single.entityId, 'sale-1');
        expect(audit.entries.single.actorUserId, 'admin-1');
      },
    );

    blocTest<SalesBloc, SalesState>(
      'emits failure when sales load fails',
      build: () => SalesBloc(
        repository: _SalesRepositoryFake(
          salesResult: const AppFailureResult(
            AppFailure(code: 'sales_error', message: 'Error'),
          ),
        ),
        auditLogRepository: AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(
        SalesLoadRequested(
          from: DateTime(2026, 6, 23),
          to: DateTime(2026, 6, 24),
        ),
      ),
      expect: () => const [
        SalesLoading(),
        SalesFailure(AppFailure(code: 'sales_error', message: 'Error')),
      ],
    );
  });
}

late AuditLogRepositoryFake audit;

final class _SalesRepositoryFake implements ISalesRepository {
  _SalesRepositoryFake({
    this.salesResult = const AppSuccess([]),
    this.itemsResult = const AppSuccess([]),
    this.voidResult,
  });

  final AppResult<List<Sale>> salesResult;
  final AppResult<List<SaleItem>> itemsResult;
  final AppResult<Sale>? voidResult;

  @override
  Future<AppResult<List<Sale>>> getSales({
    required DateTime from,
    required DateTime to,
  }) async {
    return salesResult;
  }

  @override
  Future<AppResult<List<Sale>>> getSalesByCashRegisterSession(
    String sessionId,
  ) async {
    return salesResult;
  }

  @override
  Future<AppResult<List<SaleItem>>> getSaleItems(String saleId) async {
    return itemsResult;
  }

  @override
  Future<AppResult<List<SaleVoid>>> getSaleVoids({
    required DateTime from,
    required DateTime to,
  }) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<Sale>> saveSale({
    required Sale sale,
    required List<SaleItem> items,
  }) async {
    return AppSuccess(sale);
  }

  @override
  Future<AppResult<Sale>> voidSale({
    required String saleId,
    required String reason,
    required String voidedBy,
  }) async {
    return voidResult ??
        AppSuccess(
          Sale(
            id: saleId,
            invoiceNumber: 'F-0001',
            paymentMethodId: 'cash',
            status: SaleStatus.voided,
            subtotalInCents: 500,
            totalInCents: 500,
            createdAt: DateTime(2026, 6, 23),
          ),
        );
  }
}

final class AuditLogRepositoryFake implements IAuditLogRepository {
  final List<AuditLogEntry> entries = [];

  @override
  Future<AppResult<List<AuditLogEntry>>> getEntriesByDate(DateTime date) async {
    return AppSuccess(entries);
  }

  @override
  Future<AppResult<AuditLogEntry>> saveEntry(AuditLogEntry entry) async {
    entries.add(entry);
    return AppSuccess(entry);
  }
}
