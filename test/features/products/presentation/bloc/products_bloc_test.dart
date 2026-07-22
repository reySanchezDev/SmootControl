import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/repositories/i_products_repository.dart';
import 'package:smoo_control/features/products/presentation/bloc/products_bloc.dart';
import 'package:smoo_control/features/products/presentation/bloc/products_event.dart';
import 'package:smoo_control/features/products/presentation/bloc/products_state.dart';

void main() {
  group('ProductsBloc', () {
    const product = Product(
      id: 'product-1',
      categoryId: 'category-1',
      name: 'Espresso',
      priceInCents: 350,
      costInCents: 100,
      isActive: true,
    );

    blocTest<ProductsBloc, ProductsState>(
      'loads products',
      build: () => ProductsBloc(
        repository: _ProductsRepositoryFake(
          productsResult: const AppSuccess([product]),
        ),
        auditLogRepository: _AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(const ProductsLoadRequested()),
      expect: () => const [
        ProductsLoading(),
        ProductsLoaded([product]),
      ],
    );

    blocTest<ProductsBloc, ProductsState>(
      'emits failure when loading fails',
      build: () => ProductsBloc(
        repository: _ProductsRepositoryFake(
          productsResult: const AppFailureResult(
            AppFailure(code: 'products_error', message: 'Error'),
          ),
        ),
        auditLogRepository: _AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(const ProductsLoadRequested()),
      expect: () => const [
        ProductsLoading(),
        ProductsFailure(AppFailure(code: 'products_error', message: 'Error')),
      ],
    );

    late _AuditLogRepositoryFake auditRepository;

    blocTest<ProductsBloc, ProductsState>(
      'audits product save',
      build: () {
        auditRepository = _AuditLogRepositoryFake();

        return ProductsBloc(
          repository: _ProductsRepositoryFake(
            productsResult: const AppSuccess([product]),
          ),
          auditLogRepository: auditRepository,
        );
      },
      act: (bloc) => bloc.add(const ProductSaved(product)),
      expect: () => const [
        ProductsLoading(),
        ProductsLoaded([product], successMessage: 'product_saved'),
      ],
      verify: (_) {
        expect(auditRepository.entries.single.action, 'products.save');
        expect(auditRepository.entries.single.entityId, product.id);
        expect(
          auditRepository.entries.single.details['isAvailableInPos'],
          isTrue,
        );
      },
    );
  });
}

final class _ProductsRepositoryFake implements IProductsRepository {
  _ProductsRepositoryFake({
    required this.productsResult,
  });

  final AppResult<List<Product>> productsResult;

  @override
  Future<AppResult<List<Product>>> getProducts() async {
    return productsResult;
  }

  @override
  Future<AppResult<Product>> saveProduct(Product product) async {
    return AppSuccess(product);
  }
}

final class _AuditLogRepositoryFake implements IAuditLogRepository {
  final List<AuditLogEntry> entries = [];

  @override
  Future<AppResult<List<AuditLogEntry>>> getEntriesByDate(DateTime date) async {
    return AppSuccess(entries);
  }

  @override
  Future<AppResult<AuditLogEntry>> saveEntry(AuditLogEntry entry) async {
    entries.add(entry);
    return AppSuccess(entry);
  }
}
