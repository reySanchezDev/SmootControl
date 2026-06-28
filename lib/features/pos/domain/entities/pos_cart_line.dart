import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

/// Product line currently held in the POS cart.
final class PosCartLine extends Equatable {
  /// Creates a cart line.
  const PosCartLine({
    required this.product,
    required this.quantity,
    this.isServed = false,
    this.ticketLineId = '',
    this.selectedOptions = const [],
  });

  /// Product added to the cart.
  final Product product;

  /// Selected quantity.
  final int quantity;

  /// Whether the line has already been served.
  final bool isServed;

  /// Stable identifier for this visual ticket row.
  final String ticketLineId;

  /// Options selected when this line was added.
  final List<SelectedProductOption> selectedOptions;

  /// Stable key for product plus options.
  String get cartKey {
    final options = selectedOptions
        .map((option) => '${option.groupName}:${option.optionName}')
        .join('|');
    return '${product.id}|$options';
  }

  /// Stable key for this visual line.
  String get lineKey {
    if (ticketLineId.isNotEmpty) return ticketLineId;
    return selectedOptions.isEmpty ? product.id : cartKey;
  }

  /// Human readable selected options.
  String get selectedOptionsLabel {
    return selectedOptions
        .map((option) => '${option.groupName}: ${option.optionName}')
        .join(' - ');
  }

  /// Total amount for this line.
  int get totalInCents => product.priceInCents * quantity;

  /// Returns a copy incrementing quantity by one.
  PosCartLine incremented() {
    return PosCartLine(
      product: product,
      quantity: quantity + 1,
      isServed: isServed,
      ticketLineId: ticketLineId,
      selectedOptions: selectedOptions,
    );
  }

  /// Returns a copy decrementing quantity by one without going below one.
  PosCartLine decremented() {
    return PosCartLine(
      product: product,
      quantity: quantity <= 1 ? 1 : quantity - 1,
      isServed: isServed,
      ticketLineId: ticketLineId,
      selectedOptions: selectedOptions,
    );
  }

  /// Returns a copy with selected fields replaced.
  PosCartLine copyWith({
    Product? product,
    int? quantity,
    bool? isServed,
    String? ticketLineId,
    List<SelectedProductOption>? selectedOptions,
  }) {
    return PosCartLine(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      isServed: isServed ?? this.isServed,
      ticketLineId: ticketLineId ?? this.ticketLineId,
      selectedOptions: selectedOptions ?? this.selectedOptions,
    );
  }

  @override
  List<Object?> get props => [
    product,
    quantity,
    isServed,
    ticketLineId,
    selectedOptions,
  ];
}
