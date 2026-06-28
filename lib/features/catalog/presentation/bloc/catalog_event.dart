import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';

/// Base event for catalog state management.
sealed class CatalogEvent extends Equatable {
  /// Creates a catalog event.
  const CatalogEvent();

  @override
  List<Object?> get props => [];
}

/// Loads product categories.
final class CatalogLoadRequested extends CatalogEvent {
  /// Creates a load event.
  const CatalogLoadRequested();
}

/// Saves a category or subcategory.
final class CatalogCategorySaved extends CatalogEvent {
  /// Creates a save event.
  const CatalogCategorySaved(this.category);

  /// Category to persist.
  final ProductCategory category;

  @override
  List<Object?> get props => [category];
}

/// Removes a subcategory or nested level from active use.
final class CatalogCategoryRemoved extends CatalogEvent {
  /// Creates a remove event.
  const CatalogCategoryRemoved(this.category);

  /// Category level to remove.
  final ProductCategory category;

  @override
  List<Object?> get props => [category];
}
