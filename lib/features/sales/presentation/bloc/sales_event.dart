import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';

/// Base event for sales state management.
sealed class SalesEvent extends Equatable {
  /// Creates a sales event.
  const SalesEvent();

  @override
  List<Object?> get props => [];
}

/// Loads sales for a date range.
final class SalesLoadRequested extends SalesEvent {
  /// Creates a load event.
  const SalesLoadRequested({
    required this.from,
    required this.to,
  });

  /// Start date.
  final DateTime from;

  /// End date.
  final DateTime to;

  @override
  List<Object?> get props => [from, to];
}

/// Loads the detail for one sale.
final class SaleItemsLoadRequested extends SalesEvent {
  /// Creates a sale items load event.
  const SaleItemsLoadRequested(this.saleId);

  /// Sale identifier.
  final String saleId;

  @override
  List<Object?> get props => [saleId];
}

/// Saves a completed sale and its detail.
final class SaleSaved extends SalesEvent {
  /// Creates a sale save event.
  const SaleSaved({
    required this.sale,
    required this.items,
  });

  /// Sale to persist.
  final Sale sale;

  /// Historical sale items.
  final List<SaleItem> items;

  @override
  List<Object?> get props => [sale, items];
}

/// Voids a sale with audit information.
final class SaleVoided extends SalesEvent {
  /// Creates a sale void event.
  const SaleVoided({
    required this.saleId,
    required this.reason,
    required this.voidedBy,
  });

  /// Sale identifier.
  final String saleId;

  /// Void reason.
  final String reason;

  /// User that voided the sale.
  final String voidedBy;

  @override
  List<Object?> get props => [saleId, reason, voidedBy];
}
