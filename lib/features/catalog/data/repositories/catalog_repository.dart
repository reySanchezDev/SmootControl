import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/catalog/data/datasources/local_catalog_datasource.dart';
import 'package:smoo_control/features/catalog/data/models/product_category_model.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/catalog/domain/repositories/i_catalog_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

/// Catalog repository backed by the local offline database.
final class CatalogRepository implements ICatalogRepository {
  /// Creates a catalog repository.
  const CatalogRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
    ISyncRemoteSender? remoteSender,
  }) : _syncQueueRepository = syncQueueRepository,
       _remoteSender = remoteSender;

  final LocalCatalogDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;
  final ISyncRemoteSender? _remoteSender;

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
      await _pushCategoryRemote(category);
      final saved = await _localDataSource.saveCategory(model);
      final entity = saved.toEntity();
      if (_remoteSender == null) {
        await _enqueueCategory(entity);
      }

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
      if (_remoteSender != null) {
        await _pushRemovedCategoryRemote(category);
      }
      await _localDataSource.removeCategoryLevel(
        categoryId: category.id,
        parentId: parentId,
      );
      if (_remoteSender == null) {
        await _enqueueRemovedCategory(category);
      }

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
      payload: _categoryPayload(category),
    );
  }

  Future<void> _pushCategoryRemote(ProductCategory category) async {
    final remoteSender = _remoteSender;
    if (remoteSender == null) return;

    await remoteSender.push(
      _syncItem(
        entityType: 'product_categories',
        entityId: category.id,
        operation: SyncOperation.create,
        payload: _categoryPayload(category),
      ),
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

  Future<void> _pushRemovedCategoryRemote(ProductCategory category) async {
    final remoteSender = _remoteSender;
    if (remoteSender == null) return;

    await remoteSender.push(
      _syncItem(
        entityType: 'product_categories',
        entityId: category.id,
        operation: SyncOperation.delete,
        payload: {
          'id': category.id,
          'name': category.name,
          'parentId': category.parentId,
        },
      ),
    );
  }

  Map<String, Object?> _categoryPayload(ProductCategory category) {
    return {
      'id': category.id,
      'name': category.name,
      'parentId': category.parentId,
      'sortOrder': category.sortOrder,
      'isActive': category.isActive,
    };
  }

  SyncQueueItem _syncItem({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, Object?> payload,
  }) {
    final now = DateTime.now();
    return SyncQueueItem(
      id: 'admin-direct-$entityType-$entityId',
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      status: SyncQueueStatus.pending,
      retryCount: 0,
      createdAt: now,
      updatedAt: now,
    );
  }
}
