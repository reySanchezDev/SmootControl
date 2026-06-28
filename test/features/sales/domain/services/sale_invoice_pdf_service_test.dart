import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sales/domain/services/sale_invoice_pdf_service.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SaleInvoicePdfService', () {
    test('builds a basic sale PDF', () async {
      const service = SaleInvoicePdfService();
      final createdAt = DateTime(2026, 6, 23, 10, 30);
      final bytes = await service.buildPdf(
        sale: Sale(
          id: 'sale-1',
          invoiceNumber: 'F-100',
          paymentMethodId: 'cash',
          status: SaleStatus.completed,
          subtotalInCents: 12000,
          totalInCents: 12000,
          createdAt: createdAt,
        ),
        items: [
          SaleItem(
            id: 'item-1',
            saleId: 'sale-1',
            productId: 'coffee',
            productName: 'Cafe',
            categoryName: 'Bebidas',
            quantity: 2,
            unitPriceInCents: 6000,
            unitCostInCents: 2500,
            createdAt: createdAt,
          ),
        ],
        settings: const BusinessSettings(
          businessName: 'Casa del Cafe',
          showCompanyInfoOnReceipts: true,
          invoicePrefix: 'F',
          initialInvoiceNumber: 100,
          nextInvoiceNumber: 101,
        ),
        paymentMethodName: 'Efectivo',
      );

      expect(bytes, isNotEmpty);
      expect(bytes.take(4), [37, 80, 68, 70]);
    });
  });
}
