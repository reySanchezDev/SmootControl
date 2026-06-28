import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/reports/domain/entities/report_summary.dart';
import 'package:smoo_control/features/reports/domain/services/report_summary_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportSummaryPdfService', () {
    test('builds a basic report PDF', () async {
      const service = ReportSummaryPdfService();
      final bytes = await service.buildPdf(
        ReportSummary(
          from: DateTime(2026, 6),
          to: DateTime(2026, 6, 2),
          cashDifferenceInCents: 0,
          cashExpectedInCents: 10000,
          cashExpensesInCents: 0,
          cashOpeningInCents: 10000,
          cashPhysicalInCents: 10000,
          cashSalesInCents: 0,
          cashSessionsCount: 1,
          salesCount: 0,
          voidsCount: 0,
          grossSalesInCents: 0,
          grossProfitInCents: 0,
          expensesInCents: 0,
          expenses: const [],
          netProfitInCents: 0,
          averageTicketInCents: 0,
          topProducts: const [],
          lowestProducts: const [],
          voids: const [],
        ),
      );

      expect(bytes, isNotEmpty);
      expect(bytes.take(4), [37, 80, 68, 70]);
    });
  });
}
