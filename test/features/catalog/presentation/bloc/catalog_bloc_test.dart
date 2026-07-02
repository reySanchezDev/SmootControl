import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/catalog/domain/repositories/i_catalog_repository.dart';
import 'package:smoo_control/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:smoo_control/features/catalog/presentation/bloc/catalog_event.dart';
import 'package:smoo_control/features/catalog/presentation/bloc/catalog_state.dart';

void main() {
  group('CatalogBloc', () {
    const category = ProductCategory(
      id: 'category-1',
      name: 'Cafe Caliente',
      sortOrder: 1,
      isActive: true,
    );

    blocTest<CatalogBloc, CatalogState>(
      'loads categories',
      build: () => CatalogBloc(
        repository: _CatalogRepositoryFake(
          categoriesResult: const AppSuccess([category]),
        ),
        auditLogRepository: _AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(const CatalogLoadRequested()),
      expect: () => const [
        CatalogLoading(),
        CatalogLoaded([category]),
      ],
    );

    blocTest<CatalogBloc, CatalogState>(
      'emits failure when loading fails',
      build: () => CatalogBloc(
        repository: _CatalogRepositoryFake(
          categoriesResult: const AppFailureResult(
            AppFailure(code: 'catalog_error', message: 'Error'),
          ),
        ),
        auditLogRepository: _AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(const CatalogLoadRequested()),
      expect: () => const [
        CatalogLoading(),
        CatalogFailure(AppFailure(code: 'catalog_error', message: 'Error')),
      ],
    );

    late _AuditLogRepositoryFake auditRepository;

    blocTest<CatalogBloc, CatalogState>(
      'audits category save',
      build: () {
        auditRepository = _AuditLogRepositoryFake();

        return CatalogBloc(
          repository: _CatalogRepositoryFake(
            categoriesResult: const AppSuccess([category]),
          ),
          auditLogRepository: auditRepository,
        );
      },
      act: (bloc) => bloc.add(const CatalogCategorySaved(category)),
      expect: () => const [
        CatalogLoading(),
        CatalogLoaded(
          [category],
          notice: 'Categoria guardada correctamente.',
        ),
      ],
      verify: (_) {
        expect(auditRepository.entries.single.action, 'catalog.category.save');
        expect(auditRepository.entries.single.entityId, category.id);
      },
    );

    blocTest<CatalogBloc, CatalogState>(
      'removes subcategory levels and writes audit log',
      build: () {
        auditRepository = _AuditLogRepositoryFake();

        return CatalogBloc(
          repository: _CatalogRepositoryFake(
            categoriesResult: const AppSuccess([category]),
          ),
          auditLogRepository: auditRepository,
        );
      },
      act: (bloc) {
        const subcategory = ProductCategory(
          id: 'subcategory-1',
          name: '12 Oz',
          parentId: 'category-1',
          sortOrder: 1,
          isActive: true,
        );
        bloc.add(const CatalogCategoryRemoved(subcategory));
      },
      expect: () => const [
        CatalogLoading(),
        CatalogLoaded(
          [category],
          notice: 'Categoria actualizada correctamente.',
        ),
      ],
      verify: (_) {
        expect(
          auditRepository.entries.single.action,
          'catalog.category.remove',
        );
        expect(auditRepository.entries.single.entityId, 'subcategory-1');
      },
    );
  });
}

final class _CatalogRepositoryFake implements ICatalogRepository {
  _CatalogRepositoryFake({
    required this.categoriesResult,
  });

  final AppResult<List<ProductCategory>> categoriesResult;

  @override
  Future<AppResult<List<ProductCategory>>> getCategories() async {
    return categoriesResult;
  }

  @override
  Future<AppResult<ProductCategory>> saveCategory(
    ProductCategory category,
  ) async {
    return AppSuccess(category);
  }

  @override
  Future<AppResult<ProductCategory>> removeCategoryLevel(
    ProductCategory category,
  ) async {
    return AppSuccess(category);
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
