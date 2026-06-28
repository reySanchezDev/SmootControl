import 'package:equatable/equatable.dart';

/// Item added to an open table or account before invoicing.
final class SaleItemDraft extends Equatable {
  /// Creates a sale item draft.
  const SaleItemDraft({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceInCents,
    this.selectedOptionsLabel,
  });

  /// Unique draft item identifier.
  final String id;

  /// Product identifier.
  final String productId;

  /// Product name copied for fast display.
  final String productName;

  /// Selected options copied for display and sale history.
  final String? selectedOptionsLabel;

  /// Item quantity.
  final int quantity;

  /// Unit price stored in minor currency units.
  final int unitPriceInCents;

  /// Total line amount.
  int get totalInCents => quantity * unitPriceInCents;

  @override
  List<Object?> get props => [
    id,
    productId,
    productName,
    selectedOptionsLabel,
    quantity,
    unitPriceInCents,
  ];
}
