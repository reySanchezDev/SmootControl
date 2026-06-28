import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

/// Product line stored locally for an open POS table ticket.
final class PosOpenTicketLine extends Equatable {
  /// Creates an open ticket line.
  const PosOpenTicketLine({
    required this.lineKey,
    required this.tableId,
    required this.productId,
    required this.quantity,
    this.isServed = false,
    this.selectedOptions = const [],
  });

  /// Stable visual row identifier inside the open ticket.
  final String lineKey;

  /// Table that owns the open ticket line.
  final String tableId;

  /// Product selected in the open ticket.
  final String productId;

  /// Persisted quantity.
  final int quantity;

  /// Whether this open ticket line has already been served.
  final bool isServed;

  /// Selected POS options copied from the cart line.
  final List<SelectedProductOption> selectedOptions;

  @override
  List<Object?> get props => [
    tableId,
    lineKey,
    productId,
    quantity,
    isServed,
    selectedOptions,
  ];
}
