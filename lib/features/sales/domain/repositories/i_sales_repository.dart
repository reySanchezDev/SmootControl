import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';

/// Contract for sales persistence.
abstract interface class ISalesRepository {
  /// Returns sales between two dates.
  Future<AppResult<List<Sale>>> getSales({
    required DateTime from,
    required DateTime to,
  });

  /// Returns sales for one cash register session.
  Future<AppResult<List<Sale>>> getSalesByCashRegisterSession(
    String sessionId,
  );

  /// Returns sale items for a sale.
  Future<AppResult<List<SaleItem>>> getSaleItems(String saleId);

  /// Returns auditable sale voids between two dates.
  Future<AppResult<List<SaleVoid>>> getSaleVoids({
    required DateTime from,
    required DateTime to,
  });

  /// Saves a completed sale with its historical details.
  Future<AppResult<Sale>> saveSale({
    required Sale sale,
    required List<SaleItem> items,
  });

  /// Voids a sale while preserving audit data.
  Future<AppResult<Sale>> voidSale({
    required String saleId,
    required String reason,
    required String voidedBy,
  });
}
