import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';

/// Base products state.
sealed class ProductsState extends Equatable {
  /// Creates a products state.
  const ProductsState();

  @override
  List<Object?> get props => [];
}

/// Initial products state.
final class ProductsInitial extends ProductsState {
  /// Creates the initial state.
  const ProductsInitial();
}

/// Products loading state.
final class ProductsLoading extends ProductsState {
  /// Creates a loading state.
  const ProductsLoading();
}

/// Products loaded state.
final class ProductsLoaded extends ProductsState {
  /// Creates a loaded state.
  const ProductsLoaded(this.products);

  /// Available products.
  final List<Product> products;

  @override
  List<Object?> get props => [products];
}

/// Products failure state.
final class ProductsFailure extends ProductsState {
  /// Creates a failure state.
  const ProductsFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
