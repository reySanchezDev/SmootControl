import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/products/domain/repositories/i_products_repository.dart';
import 'package:smoo_control/features/products/presentation/bloc/products_event.dart';
import 'package:smoo_control/features/products/presentation/bloc/products_state.dart';
import 'package:uuid/uuid.dart';

/// BLoC for product management.
final class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  /// Creates a products BLoC.
  ProductsBloc({
    required IProductsRepository repository,
    required IAuditLogRepository auditLogRepository,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _auditLogRepository = auditLogRepository,
       _uuid = uuid,
       super(const ProductsInitial()) {
    on<ProductsLoadRequested>(_onLoadRequested);
    on<ProductSaved>(_onProductSaved);
  }

  final IProductsRepository _repository;
  final IAuditLogRepository _auditLogRepository;
  final Uuid _uuid;

  Future<void> _onLoadRequested(
    ProductsLoadRequested event,
    Emitter<ProductsState> emit,
  ) async {
    emit(const ProductsLoading());
    final result = await _repository.getProducts();
    emit(
      result.when(
        success: ProductsLoaded.new,
        failure: ProductsFailure.new,
      ),
    );
  }

  Future<void> _onProductSaved(
    ProductSaved event,
    Emitter<ProductsState> emit,
  ) async {
    emit(const ProductsLoading());
    final saveResult = await _repository.saveProduct(event.product);

    switch (saveResult) {
      case AppFailureResult(:final error):
        emit(ProductsFailure(error));
        return;
      case AppSuccess():
        break;
    }

    await _auditLogRepository.saveEntry(
      AuditLogEntry(
        id: _uuid.v4(),
        action: 'products.save',
        entityName: 'products',
        entityId: event.product.id,
        details: {
          'name': event.product.name,
          'categoryId': event.product.categoryId,
          'isActive': event.product.isActive,
          'isAvailableInPos': event.product.isAvailableInPos,
          'modifierGroupCount': event.product.modifierGroupIds.length,
        },
        occurredAt: DateTime.now(),
      ),
    );

    final loadResult = await _repository.getProducts();
    emit(
      loadResult.when(
        success: (products) => ProductsLoaded(
          products,
          successMessage: 'product_saved',
        ),
        failure: ProductsFailure.new,
      ),
    );
  }
}
