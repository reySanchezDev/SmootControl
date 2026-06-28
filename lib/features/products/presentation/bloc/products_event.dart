import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';

/// Base event for products state management.
sealed class ProductsEvent extends Equatable {
  /// Creates a products event.
  const ProductsEvent();

  @override
  List<Object?> get props => [];
}

/// Loads products.
final class ProductsLoadRequested extends ProductsEvent {
  /// Creates a load event.
  const ProductsLoadRequested();
}

/// Saves a product.
final class ProductSaved extends ProductsEvent {
  /// Creates a save event.
  const ProductSaved(this.product);

  /// Product to persist.
  final Product product;

  @override
  List<Object?> get props => [product];
}
