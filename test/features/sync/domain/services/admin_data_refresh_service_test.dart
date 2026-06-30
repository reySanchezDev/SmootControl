import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/domain/services/admin_data_refresh_service.dart';
import 'package:smoo_control/features/sync/domain/services/catalog_pull_summary.dart';
import 'package:smoo_control/features/sync/domain/services/i_catalog_pull_service.dart';

void main() {
  group('AdminDataRefreshService', () {
    test('refreshes only the requested product scope', () async {
      final pullService = _CatalogPullServiceSpy();
      final service = AdminDataRefreshService(pullService);

      final result = await service.refreshProducts();

      expect(result, isA<AppSuccess<void>>());
      expect(pullService.fullPullCount, isZero);
      expect(pullService.scopes, [
        {CatalogPullScope.products},
      ]);
    });

    test('keeps the full pull available when no scope is requested', () async {
      final pullService = _CatalogPullServiceSpy();
      final service = AdminDataRefreshService(pullService);

      final result = await service.refresh();

      expect(result, isA<AppSuccess<void>>());
      expect(pullService.fullPullCount, 1);
      expect(pullService.scopes, isEmpty);
    });
  });
}

final class _CatalogPullServiceSpy implements ICatalogPullService {
  int fullPullCount = 0;
  final List<Set<CatalogPullScope>> scopes = [];

  @override
  Future<CatalogPullSummary> pullOperationalCatalog() async {
    fullPullCount++;
    return const CatalogPullSummary.empty();
  }

  @override
  Future<CatalogPullSummary> pullScopes(Set<CatalogPullScope> scopes) async {
    this.scopes.add({...scopes});
    return const CatalogPullSummary.empty();
  }
}
