/// An ingredient referenced by its canonical item identity.
final class CanonicalRecipeLine {
  /// Creates a recipe component.
  const CanonicalRecipeLine({
    required this.componentItemId,
    required this.unitId,
    required this.quantity,
    this.wastePercent = 0,
  });

  /// Reads one persisted ingredient row.
  factory CanonicalRecipeLine.fromRow(Map<String, Object?> row) {
    return CanonicalRecipeLine(
      componentItemId: row['component_item_id']?.toString() ?? '',
      unitId: row['unit_id']?.toString() ?? '',
      quantity: double.tryParse(row['quantity'].toString()) ?? 0,
      wastePercent: double.tryParse(row['waste_percent'].toString()) ?? 0,
    );
  }

  /// Component UUID in the same restaurant.
  final String componentItemId;

  /// Unit selected for this component.
  final String unitId;

  /// Quantity in the unit declared by [unitId].
  final double quantity;

  /// Additional waste percentage.
  final double wastePercent;

  /// Payload for the authenticated recipe writer.
  Map<String, Object?> toPayload(int order) => {
    'component_item_id': componentItemId,
    'unit_id': unitId,
    'quantity': quantity,
    'waste_percent': wastePercent,
    'display_order': order,
  };


}

/// A versioned canonical recipe, preserving the previous versions.
final class CanonicalRecipe {
  /// Creates a persisted recipe.
  const CanonicalRecipe({
    required this.id,
    required this.itemId,
    required this.version,
    required this.lines,
  });

  /// Recipe UUID.
  final String id;

  /// Parent article UUID.
  final String itemId;

  /// Immutable business revision.
  final int version;

  /// Active recipe lines.
  final List<CanonicalRecipeLine> lines;
}
