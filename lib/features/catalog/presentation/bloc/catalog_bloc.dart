import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/catalog/domain/repositories/i_catalog_repository.dart';
import 'package:smoo_control/features/catalog/presentation/bloc/catalog_event.dart';
import 'package:smoo_control/features/catalog/presentation/bloc/catalog_state.dart';
import 'package:smoo_control/features/sync/domain/services/admin_data_refresh_service.dart';
import 'package:uuid/uuid.dart';

/// BLoC for category and subcategory management.
final class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  /// Creates a catalog BLoC.
  CatalogBloc({
    required ICatalogRepository repository,
    required IAuditLogRepository auditLogRepository,
    AdminDataRefreshService? remoteRefreshService,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _auditLogRepository = auditLogRepository,
       _remoteRefreshService = remoteRefreshService,
       _uuid = uuid,
       super(const CatalogInitial()) {
    on<CatalogLoadRequested>(_onLoadRequested);
    on<CatalogCategorySaved>(_onCategorySaved);
    on<CatalogCategoryRemoved>(_onCategoryRemoved);
  }

  final ICatalogRepository _repository;
  final IAuditLogRepository _auditLogRepository;
  final AdminDataRefreshService? _remoteRefreshService;
  final Uuid _uuid;

  Future<void> _onLoadRequested(
    CatalogLoadRequested event,
    Emitter<CatalogState> emit,
  ) async {
    emit(const CatalogLoading());
    if (!await _refreshRemoteCache(emit)) return;
    final result = await _repository.getCategories();
    emit(
      result.when(
        success: CatalogLoaded.new,
        failure: CatalogFailure.new,
      ),
    );
  }

  Future<void> _onCategorySaved(
    CatalogCategorySaved event,
    Emitter<CatalogState> emit,
  ) async {
    emit(const CatalogLoading());
    final saveResult = await _repository.saveCategory(event.category);

    switch (saveResult) {
      case AppFailureResult(:final error):
        emit(CatalogFailure(error));
        return;
      case AppSuccess():
        break;
    }

    await _auditLogRepository.saveEntry(
      AuditLogEntry(
        id: _uuid.v4(),
        action: 'catalog.category.save',
        entityName: 'product_categories',
        entityId: event.category.id,
        details: {
          'name': event.category.name,
          'parentId': event.category.parentId,
          'isActive': event.category.isActive,
        },
        occurredAt: DateTime.now(),
      ),
    );

    final loadResult = await _repository.getCategories();
    emit(
      loadResult.when(
        success: (categories) => CatalogLoaded(
          categories,
          notice: 'Categoria guardada correctamente.',
        ),
        failure: CatalogFailure.new,
      ),
    );
  }

  Future<void> _onCategoryRemoved(
    CatalogCategoryRemoved event,
    Emitter<CatalogState> emit,
  ) async {
    final currentCategories = await _currentCategories();
    if (event.category.parentId == null) {
      emit(CatalogLoaded(currentCategories));
      return;
    }

    emit(const CatalogLoading());
    final removeResult = await _repository.removeCategoryLevel(event.category);

    if (removeResult case AppFailureResult(:final error)) {
      emit(CatalogFailure(error));
      return;
    }

    await _auditLogRepository.saveEntry(
      AuditLogEntry(
        id: _uuid.v4(),
        action: 'catalog.category.remove',
        entityName: 'product_categories',
        entityId: event.category.id,
        details: {
          'name': event.category.name,
          'parentId': event.category.parentId,
        },
        occurredAt: DateTime.now(),
      ),
    );

    final loadResult = await _repository.getCategories();
    emit(
      loadResult.when(
        success: (categories) => CatalogLoaded(
          categories,
          notice: 'Categoria actualizada correctamente.',
        ),
        failure: CatalogFailure.new,
      ),
    );
  }

  Future<List<ProductCategory>> _currentCategories() async {
    return switch (state) {
      CatalogLoaded(:final categories) => categories,
      _ => switch (await _repository.getCategories()) {
        AppSuccess(:final value) => value,
        AppFailureResult() => const <ProductCategory>[],
      },
    };
  }

  Future<bool> _refreshRemoteCache(Emitter<CatalogState> emit) async {
    final result = await _remoteRefreshService?.refreshCatalog();
    if (result case AppFailureResult(:final error)) {
      emit(CatalogFailure(error));
      return false;
    }
    return true;
  }
}
