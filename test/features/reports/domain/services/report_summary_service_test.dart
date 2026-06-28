import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_summary.dart';
import 'package:smoo_control/features/cash_register/domain/repositories/i_cash_register_repository.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/domain/entities/operating_expense.dart';
import 'package:smoo_control/features/expenses/domain/repositories/i_expenses_repository.dart';
import 'package:smoo_control/features/reports/domain/entities/report_period.dart';
import 'package:smoo_control/features/reports/domain/entities/report_summary.dart';
import 'package:smoo_control/features/reports/domain/services/report_summary_service.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';

part 'report_summary_service_test_fakes.dart';

void main() {
  group('ReportSummaryService', () {
    test('calculates sales, profit, expenses and product ranking', () async {
      final sale = Sale(
        id: 'sale-1',
        invoiceNumber: 'F-1',
        paymentMethodId: 'cash',
        status: SaleStatus.completed,
        subtotalInCents: 80000,
        totalInCents: 80000,
        createdAt: DateTime(2026, 6, 23, 10),
      );
      final items = [
        SaleItem(
          id: 'item-1',
          saleId: 'sale-1',
          productId: 'coffee',
          productName: 'Cafe',
          categoryName: 'Bebidas',
          quantity: 2,
          unitPriceInCents: 25000,
          unitCostInCents: 10000,
          createdAt: DateTime(2026, 6, 23, 10),
        ),
        SaleItem(
          id: 'item-2',
          saleId: 'sale-1',
          productId: 'cake',
          productName: 'Pastel',
          categoryName: 'Postres',
          quantity: 1,
          unitPriceInCents: 30000,
          unitCostInCents: 12000,
          createdAt: DateTime(2026, 6, 23, 10),
        ),
      ];
      final expense = OperatingExpense(
        id: 'expense-1',
        categoryId: 'payroll',
        amountInCents: 15000,
        description: 'Nomina',
        createdAt: DateTime(2026, 6, 23, 12),
        createdBy: 'admin',
      );
      final saleVoid = SaleVoid(
        id: 'void-1',
        saleId: 'sale-voided',
        reason: 'Error de captura',
        voidedBy: 'admin',
        voidedAt: DateTime(2026, 6, 23, 13),
      );
      final cashSession = CashRegisterSession(
        id: 'cash-1',
        cashierId: 'cashier',
        businessDate: DateTime(2026, 6, 23),
        openingCashInCents: 20000,
        physicalClosingCashInCents: 87000,
        status: CashRegisterStatus.closed,
      );
      final service = ReportSummaryService(
        cashRegisterRepository: _CashRegisterRepositoryFake(
          summaries: [
            CashRegisterSummary(
              session: cashSession,
              cashSalesInCents: 80000,
              expensesInCents: 15000,
            ),
          ],
        ),
        salesRepository: _SalesRepositoryFake(
          sales: [sale],
          itemsBySaleId: {'sale-1': items},
          voids: [saleVoid],
        ),
        expensesRepository: _ExpensesRepositoryFake(expenses: [expense]),
      );

      final result = await service.loadSummary(
        period: ReportPeriod.today,
        now: DateTime(2026, 6, 23, 15),
      );

      expect(result, isA<AppSuccess<ReportSummary>>());
      final summary = (result as AppSuccess<ReportSummary>).value;
      expect(summary.salesCount, 1);
      expect(summary.voidsCount, 1);
      expect(summary.voids, [saleVoid]);
      expect(summary.cashSessionsCount, 1);
      expect(summary.cashOpeningInCents, 20000);
      expect(summary.cashSalesInCents, 80000);
      expect(summary.cashExpensesInCents, 15000);
      expect(summary.cashExpectedInCents, 85000);
      expect(summary.cashPhysicalInCents, 87000);
      expect(summary.cashDifferenceInCents, 2000);
      expect(summary.grossSalesInCents, 80000);
      expect(summary.grossProfitInCents, 48000);
      expect(summary.expensesInCents, 15000);
      expect(summary.expenses.single.categoryId, 'payroll');
      expect(summary.expenses.single.amountInCents, 15000);
      expect(summary.netProfitInCents, 33000);
      expect(summary.averageTicketInCents, 80000);
      expect(summary.topProducts.first.productName, 'Cafe');
      expect(summary.topProducts.first.quantity, 2);
      expect(summary.lowestProducts.first.productName, 'Pastel');
      expect(summary.lowestProducts.first.quantity, 1);
    });

    test('calculates summary for a custom date range', () async {
      final includedSale = Sale(
        id: 'sale-1',
        invoiceNumber: 'F-1',
        paymentMethodId: 'cash',
        status: SaleStatus.completed,
        subtotalInCents: 10000,
        totalInCents: 10000,
        createdAt: DateTime(2026, 6, 15, 10),
      );
      final excludedSale = Sale(
        id: 'sale-2',
        invoiceNumber: 'F-2',
        paymentMethodId: 'cash',
        status: SaleStatus.completed,
        subtotalInCents: 20000,
        totalInCents: 20000,
        createdAt: DateTime(2026, 6, 22, 10),
      );
      final service = ReportSummaryService(
        cashRegisterRepository: const _CashRegisterRepositoryFake(
          summaries: [],
        ),
        salesRepository: _SalesRepositoryFake(
          sales: [includedSale, excludedSale],
          itemsBySaleId: {
            'sale-1': [
              SaleItem(
                id: 'item-1',
                saleId: 'sale-1',
                productId: 'plate',
                productName: 'Almuerzo',
                categoryName: 'Comidas',
                quantity: 1,
                unitPriceInCents: 10000,
                unitCostInCents: 4000,
                createdAt: DateTime(2026, 6, 15, 10),
              ),
            ],
          },
        ),
        expensesRepository: const _ExpensesRepositoryFake(expenses: []),
      );

      final result = await service.loadSummary(
        period: ReportPeriod.custom,
        now: DateTime(2026, 6),
        customRange: ReportDateRange(
          from: DateTime(2026, 6, 10),
          to: DateTime(2026, 6, 20),
        ),
      );

      final summary = (result as AppSuccess<ReportSummary>).value;
      expect(summary.from, DateTime(2026, 6, 10));
      expect(summary.to, DateTime(2026, 6, 20));
      expect(summary.salesCount, 1);
      expect(summary.grossSalesInCents, 10000);
      expect(summary.grossProfitInCents, 6000);
    });
  });
}
