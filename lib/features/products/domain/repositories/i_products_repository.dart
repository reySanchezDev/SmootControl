import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';

/// Contract for product persistence.
abstract interface class IProductsRepository {
  /// Returns active and inactive products.
  Future<AppResult<List<Product>>> getProducts();

  /// Saves a product.
  Future<AppResult<Product>> saveProduct(Product product);
}
