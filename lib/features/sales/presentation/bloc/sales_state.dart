import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';

/// Base sales state.
sealed class SalesState extends Equatable {
  /// Creates a sales state.
  const SalesState();

  @override
  List<Object?> get props => [];
}

/// Initial sales state.
final class SalesInitial extends SalesState {
  /// Creates the initial state.
  const SalesInitial();
}

/// Sales loading state.
final class SalesLoading extends SalesState {
  /// Creates a loading state.
  const SalesLoading();
}

/// Sales loaded state.
final class SalesLoaded extends SalesState {
  /// Creates a sales loaded state.
  const SalesLoaded(this.sales);

  /// Sales in the requested range.
  final List<Sale> sales;

  @override
  List<Object?> get props => [sales];
}

/// Sale items loaded state.
final class SaleItemsLoaded extends SalesState {
  /// Creates a sale items loaded state.
  const SaleItemsLoaded({
    required this.saleId,
    required this.items,
  });

  /// Sale identifier.
  final String saleId;

  /// Historical sale items.
  final List<SaleItem> items;

  @override
  List<Object?> get props => [saleId, items];
}

/// Sale saved state.
final class SaleSaveSuccess extends SalesState {
  /// Creates a sale saved state.
  const SaleSaveSuccess(this.sale);

  /// Persisted sale.
  final Sale sale;

  @override
  List<Object?> get props => [sale];
}

/// Sale voided state.
final class SaleVoidSuccess extends SalesState {
  /// Creates a sale voided state.
  const SaleVoidSuccess(this.sale);

  /// Voided sale.
  final Sale sale;

  @override
  List<Object?> get props => [sale];
}

/// Sales failure state.
final class SalesFailure extends SalesState {
  /// Creates a failure state.
  const SalesFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
