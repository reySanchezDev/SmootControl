import 'package:smoo_control/features/sync/domain/services/catalog_pull_summary.dart';

/// Remote catalog sections that can be downloaded independently.
enum CatalogPullScope {
  /// Restaurant and invoice configuration.
  businessSettings,

  /// Roles, permissions and operational users.
  accessControl,

  /// Product categories.
  catalog,

  /// Products and their modifier group assignments.
  products,

  /// Modifier groups and options.
  modifiers,

  /// Payment methods.
  paymentMethods,

  /// Restaurant tables.
  tables,

  /// Expense categories.
  expenseCategories,

  /// Daily exchange rates.
  exchangeRates,

  /// Sales types, packaging catalog, rules and packaging stock.
  packaging,

  /// Open/closed cash register sessions needed by POS devices.
  cashRegisterSessions,

  /// Employees and operational business rules used by POS.
  staff,
}

/// Pulls remote operational catalog data into the local POS database.
abstract interface class ICatalogPullService {
  /// Downloads catalog/configuration data and applies it locally.
  Future<CatalogPullSummary> pullOperationalCatalog();

  /// Downloads only the requested catalog/configuration sections.
  Future<CatalogPullSummary> pullScopes(Set<CatalogPullScope> scopes);
}
