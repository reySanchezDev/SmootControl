/// The server refused a sale built from an obsolete item catalog snapshot.
final class StaleItemCatalogSaleException implements Exception {
  /// Creates the typed conflict used to quarantine the queue item.
  const StaleItemCatalogSaleException();

  @override
  String toString() => 'pos_catalog_revision_stale_refresh_required';
}
