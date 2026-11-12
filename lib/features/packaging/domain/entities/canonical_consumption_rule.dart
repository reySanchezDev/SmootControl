/// Canonical packaging and consumption rule, independent from item identity.
final class CanonicalConsumptionRule {
  /// Creates a rule.
  const CanonicalConsumptionRule({
    required this.id,
    required this.consumedItemId,
    required this.unitId,
    required this.scope,
    required this.quantity,
    this.sourceItemId,
    this.salesTypeId,
    this.priority = 100,
    this.isActive = true,
  });

  /// Parses one tenant-scoped remote record.
  factory CanonicalConsumptionRule.fromRow(Map<String, Object?> row) {
    return CanonicalConsumptionRule(
      id: row['id']?.toString() ?? '',
      sourceItemId: row['source_item_id']?.toString(),
      consumedItemId: row['consumed_item_id']?.toString() ?? '',
      salesTypeId: row['sales_type_id']?.toString(),
      scope: row['scope']?.toString() ?? '',
      quantity: double.tryParse(row['quantity'].toString()) ?? 0,
      unitId: row['unit_id']?.toString() ?? '',
      priority: int.tryParse(row['priority'].toString()) ?? 100,
      isActive: row['is_active'] == true,
    );
  }

  /// Stable operation identity for idempotent RPC updates.
  final String id;

  /// Sellable article that triggers this rule, or null for global rules.
  final String? sourceItemId;

  /// Article consumed by the transaction.
  final String consumedItemId;

  /// Modality (for example takeaway), or null for every modality.
  final String? salesTypeId;

  /// Either per_order or per_sale_line.
  final String scope;

  /// Required quantity in the selected measurement unit.
  final double quantity;

  /// Unit of the consumed item.
  final String unitId;

  /// Matching precedence.
  final int priority;

  /// Whether this rule can match a transaction.
  final bool isActive;

  /// Payload accepted by the revisioned, authenticated writer.
  Map<String, Object?> toPayload() => {
    'id': id,
    'source_item_id': sourceItemId,
    'consumed_item_id': consumedItemId,
    'sales_type_id': salesTypeId,
    'scope': scope,
    'quantity': quantity,
    'unit_id': unitId,
    'priority': priority,
    'is_active': isActive,
  };
}
