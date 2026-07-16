import 'package:equatable/equatable.dart';

/// Unit used by purchases, stock and recipe ingredients.
final class MeasurementUnit extends Equatable {
  /// Creates a measurement unit.
  const MeasurementUnit({
    required this.id,
    required this.code,
    required this.name,
    required this.unitGroup,
    required this.baseFactor,
    required this.isActive,
  });

  /// Unique identifier.
  final String id;

  /// Stable short code, for example kg, oz or unit.
  final String code;

  /// User-facing name.
  final String name;

  /// Unit family: count, mass or volume.
  final String unitGroup;

  /// Conversion factor to its family base.
  final double baseFactor;

  /// Whether this unit is available for new configurations.
  final bool isActive;

  @override
  List<Object?> get props => [
    id,
    code,
    name,
    unitGroup,
    baseFactor,
    isActive,
  ];
}
