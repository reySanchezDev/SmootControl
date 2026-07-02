import 'package:equatable/equatable.dart';

/// Sales type applied to a complete POS order.
final class SalesType extends Equatable {
  /// Creates a sales type.
  const SalesType({
    required this.id,
    required this.code,
    required this.name,
    required this.displayOrder,
    required this.isDefault,
    required this.isActive,
  });

  /// Stable identifier.
  final String id;

  /// Stable code, for example dine_in or to_go.
  final String code;

  /// Visible name.
  final String name;

  /// Sorting position.
  final int displayOrder;

  /// Whether POS selects this sales type by default.
  final bool isDefault;

  /// Whether the sales type can be selected.
  final bool isActive;

  @override
  List<Object?> get props => [
    id,
    code,
    name,
    displayOrder,
    isDefault,
    isActive,
  ];
}
