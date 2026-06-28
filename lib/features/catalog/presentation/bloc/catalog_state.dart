import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';

/// Base catalog state.
sealed class CatalogState extends Equatable {
  /// Creates a catalog state.
  const CatalogState();

  @override
  List<Object?> get props => [];
}

/// Initial catalog state.
final class CatalogInitial extends CatalogState {
  /// Creates the initial state.
  const CatalogInitial();
}

/// Catalog loading state.
final class CatalogLoading extends CatalogState {
  /// Creates a loading state.
  const CatalogLoading();
}

/// Catalog loaded state.
final class CatalogLoaded extends CatalogState {
  /// Creates a loaded state.
  const CatalogLoaded(this.categories);

  /// Available categories and subcategories.
  final List<ProductCategory> categories;

  @override
  List<Object?> get props => [categories];
}

/// Catalog failure state.
final class CatalogFailure extends CatalogState {
  /// Creates a failure state.
  const CatalogFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
