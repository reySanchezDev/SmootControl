import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_stock_item.dart';

/// Inventory repository contract.
abstract interface class IInventoryRepository {
  /// Returns tracked product stock.
  Future<AppResult<List<InventoryStockItem>>> getTrackedStock();

  /// Registers a purchase movement.
  Future<AppResult<void>> registerPurchase({
    required String productId,
    required int quantity,
    required String userId,
    String? notes,
  });
}
