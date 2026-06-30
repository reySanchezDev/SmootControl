/// Raised when a sale would make tracked inventory negative.
final class InventoryStockException implements Exception {
  /// Creates the exception.
  const InventoryStockException({
    required this.productName,
    required this.available,
    required this.requested,
  });

  /// Product name.
  final String productName;

  /// Available quantity.
  final int available;

  /// Requested quantity.
  final int requested;

  @override
  String toString() {
    return 'Stock insuficiente para $productName. '
        'Disponible: $available, solicitado: $requested.';
  }
}
