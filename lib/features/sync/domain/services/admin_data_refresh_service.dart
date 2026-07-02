import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/domain/services/i_catalog_pull_service.dart';

/// Refreshes the local administrative cache from Supabase.
final class AdminDataRefreshService {
  /// Creates an administrative refresh service.
  const AdminDataRefreshService(this._catalogPullService);

  final ICatalogPullService _catalogPullService;

  /// Downloads the current remote operational snapshot into the local cache.
  Future<AppResult<void>> refresh({Set<CatalogPullScope>? scopes}) async {
    try {
      if (scopes == null || scopes.isEmpty) {
        await _catalogPullService.pullOperationalCatalog();
      } else {
        await _catalogPullService.pullScopes(scopes);
      }
      return const AppSuccess<void>(null);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'admin_remote_refresh_failed',
          message: 'No se pudieron descargar los datos administrativos.',
          cause: error,
        ),
      );
    }
  }

  /// Refreshes restaurant and invoice settings.
  Future<AppResult<void>> refreshBusinessSettings() {
    return refresh(scopes: {CatalogPullScope.businessSettings});
  }

  /// Refreshes roles, permissions and users.
  Future<AppResult<void>> refreshAccessControl() {
    return refresh(scopes: {CatalogPullScope.accessControl});
  }

  /// Refreshes product categories.
  Future<AppResult<void>> refreshCatalog() {
    return refresh(scopes: {CatalogPullScope.catalog});
  }

  /// Refreshes products plus their category/modifier dependencies.
  Future<AppResult<void>> refreshProducts() {
    return refresh(scopes: {CatalogPullScope.products});
  }

  /// Refreshes modifier groups and options.
  Future<AppResult<void>> refreshModifiers() {
    return refresh(scopes: {CatalogPullScope.modifiers});
  }

  /// Refreshes payment methods.
  Future<AppResult<void>> refreshPaymentMethods() {
    return refresh(scopes: {CatalogPullScope.paymentMethods});
  }

  /// Refreshes restaurant tables.
  Future<AppResult<void>> refreshTables() {
    return refresh(scopes: {CatalogPullScope.tables});
  }

  /// Refreshes expense categories.
  Future<AppResult<void>> refreshExpenseCategories() {
    return refresh(scopes: {CatalogPullScope.expenseCategories});
  }

  /// Refreshes daily exchange rates.
  Future<AppResult<void>> refreshExchangeRates() {
    return refresh(scopes: {CatalogPullScope.exchangeRates});
  }

  /// Refreshes sales types, packaging catalog and stock.
  Future<AppResult<void>> refreshPackaging() {
    return refresh(scopes: {CatalogPullScope.packaging});
  }
}
