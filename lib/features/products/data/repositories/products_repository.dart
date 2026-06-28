import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/products/data/datasources/local_products_datasource.dart';
import 'package:smoo_control/features/products/data/models/product_model.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/repositories/i_products_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';

/// Products repository backed by the local offline database.
final class ProductsRepository implements IProductsRepository {
  /// Creates a products repository.
  const ProductsRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
  }) : _syncQueueRepository = syncQueueRepository;

  final LocalProductsDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;

  @override
  Future<AppResult<List<Product>>> getProducts() async {
    try {
      final products = await _localDataSource.getProducts();
      return AppSuccess(products.map((product) => product.toEntity()).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'products_read_failed',
          message: 'No se pudieron leer los productos locales.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<Product>> saveProduct(Product product) async {
    try {
      final model = ProductModel.fromEntity(product);
      final saved = await _localDataSource.saveProduct(model);
      final entity = saved.toEntity();
      await _enqueueProduct(entity);

      return AppSuccess(entity);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'product_save_failed',
          message: 'No se pudo guardar el producto local.',
          cause: error,
        ),
      );
    }
  }

  Future<void> _enqueueProduct(Product product) async {
    await _syncQueueRepository?.enqueue(
      entityType: 'products',
      entityId: product.id,
      operation: SyncOperation.create,
      payload: {
        'id': product.id,
        'categoryId': product.categoryId,
        'name': product.name,
        'priceInCents': product.priceInCents,
        'costInCents': product.costInCents,
        'isActive': product.isActive,
        'isAvailableInPos': product.isAvailableInPos,
        'optionGroups': product.optionGroups
            .map(
              (group) => {
                'name': group.name,
                'options': group.options,
              },
            )
            .toList(),
        'modifierGroupIds': product.modifierGroupIds,
      },
    );
  }
}
