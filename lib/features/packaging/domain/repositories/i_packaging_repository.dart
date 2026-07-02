import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_stock_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/product_packaging_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';

/// Packaging and sales type repository contract.
abstract interface class IPackagingRepository {
  /// Returns sales types.
  Future<AppResult<List<SalesType>>> getSalesTypes();

  /// Saves a sales type.
  Future<AppResult<SalesType>> saveSalesType(SalesType salesType);

  /// Returns packaging items.
  Future<AppResult<List<PackagingItem>>> getPackagingItems();

  /// Saves a packaging item.
  Future<AppResult<PackagingItem>> savePackagingItem(PackagingItem item);

  /// Returns packaging rules.
  Future<AppResult<List<ProductPackagingRule>>> getRules();

  /// Saves a packaging rule.
  Future<AppResult<ProductPackagingRule>> saveRule(ProductPackagingRule rule);

  /// Returns packaging stock.
  Future<AppResult<List<PackagingStockItem>>> getPackagingStock();

  /// Registers a packaging purchase.
  Future<AppResult<void>> registerPackagingPurchase({
    required String packagingItemId,
    required int quantity,
    required String userId,
    String? notes,
  });
}
