/// Raised when packaging stock is not enough for a sale.
final class PackagingStockException implements Exception {
  /// Creates an insufficient packaging stock error.
  const PackagingStockException({
    required this.packagingName,
    required this.available,
    required this.requested,
  });

  /// Packaging name.
  final String packagingName;

  /// Available stock.
  final int available;

  /// Requested stock.
  final int requested;

  @override
  String toString() {
    return 'Stock insuficiente de empaque: $packagingName '
        '(disponible $available, requerido $requested).';
  }
}
