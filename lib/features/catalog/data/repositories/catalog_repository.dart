import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/catalog/data/datasources/local_catalog_datasource.dart';
import 'package:smoo_control/features/catalog/data/models/product_category_model.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/catalog/domain/repositories/i_catalog_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';

/// Catalog repository backed by the local offline database.
final class CatalogRepository implements ICatalogRepository {
  /// Creates a catalog repository.
  const CatalogRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
  }) : _syncQueueRepository = syncQueueRepository;

  final LocalCatalogDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;

  @override
  Future<AppResult<List<ProductCategory>>> getCategories() async {
    try {
      final categories = await _localDataSource.getCategories();
      return AppSuccess(
        categories.map((category) => category.toEntity()).toList(),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'catalog_read_failed',
          message: 'No se pudo leer el catalogo local.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<ProductCategory>> saveCategory(
    ProductCategory category,
  ) async {
    try {
      final model = ProductCategoryModel.fromEntity(category);
      final saved = await _localDataSource.saveCategory(model);
      final entity = saved.toEntity();
      await _enqueueCategory(entity);

      return AppSuccess(entity);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'catalog_save_failed',
          message: 'No se pudo guardar la categoria local.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<ProductCategory>> removeCategoryLevel(
    ProductCategory category,
  ) async {
    final parentId = category.parentId;
    if (parentId == null) {
      return const AppFailureResult(
        AppFailure(
          code: 'catalog_root_remove_blocked',
          message: 'No se puede quitar una categoria principal.',
        ),
      );
    }

    try {
      await _localDataSource.removeCategoryLevel(
        categoryId: category.id,
        parentId: parentId,
      );
      await _enqueueRemovedCategory(category);

      return AppSuccess(category);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'catalog_remove_failed',
          message: 'No se pudo quitar el nivel del catalogo local.',
          cause: error,
        ),
      );
    }
  }

  Future<void> _enqueueCategory(ProductCategory category) async {
    await _syncQueueRepository?.enqueue(
      entityType: 'product_categories',
      entityId: category.id,
      operation: SyncOperation.create,
      payload: {
        'id': category.id,
        'name': category.name,
        'parentId': category.parentId,
        'sortOrder': category.sortOrder,
        'isActive': category.isActive,
      },
    );
  }

  Future<void> _enqueueRemovedCategory(ProductCategory category) async {
    await _syncQueueRepository?.enqueue(
      entityType: 'product_categories',
      entityId: category.id,
      operation: SyncOperation.delete,
      payload: {
        'id': category.id,
        'name': category.name,
        'parentId': category.parentId,
      },
    );
  }
}
