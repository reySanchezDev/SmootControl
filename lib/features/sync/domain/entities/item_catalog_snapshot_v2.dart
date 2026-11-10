/// The only supported item catalog contract for the future F2 POS cutover.
///
/// This model is not wired into Drift or live synchronization. A POS must
/// validate a complete, tenant-bound snapshot before replacing local items.
library;

/// Item types supported by the canonical master.
enum ItemCatalogTypeV2 {
  /// Physical stock tracked by the item ledger.
  inventory,

  /// An article without stock ledger entries.
  nonInventory,

  /// A nonphysical commercial service.
  service,
}

/// Decision about whether a complete snapshot can replace local state.
enum ItemCatalogUpdateDecisionV2 {
  /// A newer complete snapshot can be applied atomically.
  apply,

  /// The exact same snapshot was already applied.
  noChange,
}

/// A canonical article from the server item master.
final class ItemCatalogEntryV2 {
  /// Creates an immutable catalog article.
  const ItemCatalogEntryV2({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.baseUnitId,
    required this.canSell,
    required this.visibleInPos,
    required this.isActive,
  });

  /// Canonical UUID; never a commercial code.
  final String id;

  /// Commercial article code.
  final String code;

  /// Display name.
  final String name;

  /// Inventory or commercial type.
  final ItemCatalogTypeV2 type;

  /// Canonical base measurement unit UUID.
  final String baseUnitId;

  /// Whether the article can be sold.
  final bool canSell;

  /// Whether the article appears on POS menus.
  final bool visibleInPos;

  /// Whether the article remains active.
  final bool isActive;
}

/// Unit conversion defined for an article.
final class ItemCatalogUnitV2 {
  /// Creates a unit with its exact base conversion.
  const ItemCatalogUnitV2({
    required this.itemId,
    required this.unitId,
    required this.quantityInBase,
  });

  /// Canonical article UUID.
  final String itemId;

  /// Measurement-unit UUID.
  final String unitId;

  /// Exact positive decimal string; never a floating-point approximation.
  final String quantityInBase;
}

/// Consumption policy selected for a canonical article.
final class ItemCatalogConsumptionRuleV2 {
  /// Creates an immutable consumption rule.
  const ItemCatalogConsumptionRuleV2({
    required this.id,
    required this.sourceItemId,
    required this.consumedItemId,
    required this.unitId,
    required this.scope,
    required this.quantity,
  });

  /// Rule UUID.
  final String id;

  /// Optional sellable source item; null applies to the entire order.
  final String? sourceItemId;

  /// Article consumed by this rule.
  final String consumedItemId;

  /// Unit UUID, belonging to the consumed article.
  final String unitId;

  /// One of the defined consumption scopes.
  final String scope;

  /// Exact positive decimal quantity string.
  final String quantity;
}

/// A complete, versioned snapshot of the single canonical item catalog.
final class ItemCatalogSnapshotV2 {
  /// Constructs an immutable, already validated snapshot.
  const ItemCatalogSnapshotV2._({
    required this.restaurantId,
    required this.snapshotId,
    required this.revision,
    required this.items,
    required this.units,
    required this.consumptionRules,
  });

  /// Restaurant owning the entire snapshot.
  final String restaurantId;

  /// Stable identity of this snapshot for idempotent replays.
  final String snapshotId;

  /// Strictly increasing revision issued by the backend.
  final int revision;

  /// All canonical articles, never a paginated POS-only subset.
  final List<ItemCatalogEntryV2> items;

  /// Full unit conversions for the corresponding articles.
  final List<ItemCatalogUnitV2> units;

  /// Rules referencing the canonical article identifiers.
  final List<ItemCatalogConsumptionRuleV2> consumptionRules;

  /// Validates and parses a full remote snapshot without changing local data.
  ///
  /// Throws [FormatException] if the payload is incomplete, stale-shaped,
  /// cross-tenant, has conflicting identifiers or contains invalid references.
  factory ItemCatalogSnapshotV2.fromJson(
    Map<String, Object?> json, {
    required String expectedRestaurantId,
  }) {
    final restaurantId = _uuid(json['restaurant_id'], 'restaurant_id');
    if (restaurantId != expectedRestaurantId.toLowerCase()) {
      throw const FormatException('catalog_tenant_mismatch');
    }
    if (json['contract_version'] != 2) {
      throw const FormatException('unsupported_item_catalog_version');
    }
    if (json['snapshot_complete'] != true) {
      throw const FormatException('partial_item_catalog_not_authoritative');
    }
    final revision = json['revision'];
    if (revision is! int || revision <= 0) {
      throw const FormatException('invalid_catalog_revision');
    }
    final snapshotId = _uuid(json['snapshot_id'], 'snapshot_id');
    final itemRows = _rows(json['items'], 'items');
    final unitRows = _rows(json['item_units'], 'item_units');
    final ruleRows = _rows(json['consumption_rules'], 'consumption_rules');

    final itemIds = <String>{};
    final codes = <String>{};
    final items = <ItemCatalogEntryV2>[];
    for (final row in itemRows) {
      _checkTenant(row, restaurantId);
      final id = _uuid(row['id'], 'item_id');
      final code = _text(row['code'], 'item_code');
      final name = _text(row['name'], 'item_name');
      final type = switch (row['item_type']) {
        'inventory' => ItemCatalogTypeV2.inventory,
        'non_inventory' => ItemCatalogTypeV2.nonInventory,
        'service' => ItemCatalogTypeV2.service,
        _ => throw const FormatException('unsupported_item_type'),
      };
      final canSell = _boolean(row['can_sell'], 'can_sell');
      final visibleInPos = _boolean(row['visible_in_pos'], 'visible_in_pos');
      final isActive = _boolean(row['is_active'], 'is_active');
      if (!itemIds.add(id) || !codes.add(code.toLowerCase())) {
        throw const FormatException('duplicate_catalog_item_or_code');
      }
      if (visibleInPos && (!canSell || !isActive)) {
        throw const FormatException('invalid_pos_item_visibility');
      }
      items.add(
        ItemCatalogEntryV2(
          id: id,
          code: code,
          name: name,
          type: type,
          baseUnitId: _uuid(row['base_unit_id'], 'base_unit_id'),
          canSell: canSell,
          visibleInPos: visibleInPos,
          isActive: isActive,
        ),
      );
    }

    final units = <ItemCatalogUnitV2>[];
    final unitKeys = <String>{};
    final baseKeys = <String>{};
    for (final row in unitRows) {
      _checkTenant(row, restaurantId);
      final itemId = _uuid(row['item_id'], 'unit_item_id');
      final unitId = _uuid(row['unit_id'], 'unit_id');
      final conversion = _decimal(row['quantity_in_base'], 8);
      if (!itemIds.contains(itemId)) {
        throw const FormatException('unit_references_missing_item');
      }
      final key = '$itemId/$unitId';
      if (!unitKeys.add(key)) {
        throw const FormatException('duplicate_item_unit');
      }
      final entry = items.firstWhere((item) => item.id == itemId);
      if (entry.baseUnitId == unitId) {
        if (!_isOne(conversion)) {
          throw const FormatException('invalid_base_unit_factor');
        }
        baseKeys.add(itemId);
      }
      units.add(
        ItemCatalogUnitV2(
          itemId: itemId,
          unitId: unitId,
          quantityInBase: conversion,
        ),
      );
    }
    if (baseKeys.length != itemIds.length) {
      throw const FormatException('missing_item_base_unit');
    }

    final rules = <ItemCatalogConsumptionRuleV2>[];
    final ruleIds = <String>{};
    for (final row in ruleRows) {
      _checkTenant(row, restaurantId);
      final id = _uuid(row['id'], 'rule_id');
      final source = row['source_item_id'] == null
          ? null
          : _uuid(row['source_item_id'], 'source_item_id');
      final consumed = _uuid(row['consumed_item_id'], 'consumed_item_id');
      final unitId = _uuid(row['unit_id'], 'rule_unit_id');
      final scope = _text(row['scope'], 'rule_scope');
      final quantity = _decimal(row['quantity'], 6);
      if (!ruleIds.add(id)) {
        throw const FormatException('duplicate_consumption_rule');
      }
      if (scope != 'per_order' && scope != 'per_sale_line') {
        throw const FormatException('unsupported_consumption_scope');
      }
      if (scope == 'per_sale_line' && source == null) {
        throw const FormatException('consumption_line_without_source');
      }
      if (source != null &&
          !items.any((item) => item.id == source && item.canSell)) {
        throw const FormatException('invalid_consumption_source');
      }
      if (!items.any(
        (item) =>
            item.id == consumed && item.type != ItemCatalogTypeV2.service,
      )) {
        throw const FormatException('invalid_consumed_item');
      }
      if (!unitKeys.contains('$consumed/$unitId')) {
        throw const FormatException('consumption_unit_not_configured');
      }
      rules.add(
        ItemCatalogConsumptionRuleV2(
          id: id,
          sourceItemId: source,
          consumedItemId: consumed,
          unitId: unitId,
          scope: scope,
          quantity: quantity,
        ),
      );
    }
    return ItemCatalogSnapshotV2._(
      restaurantId: restaurantId,
      snapshotId: snapshotId,
      revision: revision,
      items: List.unmodifiable(items),
      units: List.unmodifiable(units),
      consumptionRules: List.unmodifiable(rules),
    );
  }

  /// Rejects out-of-order snapshots and conflicting equal-revision payloads.
  ///
  /// A caller must commit all three collections in one local transaction,
  /// together with this revision and snapshot identifier.
  ItemCatalogUpdateDecisionV2 decideAgainst({
    required int? storedRevision,
    required String? storedSnapshotId,
  }) {
    if (storedRevision == null) return ItemCatalogUpdateDecisionV2.apply;
    if (revision < storedRevision) {
      throw const FormatException('stale_item_catalog_snapshot');
    }
    if (revision == storedRevision) {
      if (snapshotId != storedSnapshotId) {
        throw const FormatException('item_catalog_revision_conflict');
      }
      return ItemCatalogUpdateDecisionV2.noChange;
    }
    return ItemCatalogUpdateDecisionV2.apply;
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final RegExp _decimalPattern = RegExp(
    r'^(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$',
  );

  static String _uuid(Object? value, String label) {
    if (value is! String || !_uuidPattern.hasMatch(value)) {
      throw FormatException('invalid_$label');
    }
    return value.toLowerCase();
  }

  static String _text(Object? value, String label) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('invalid_$label');
    }
    return value.trim();
  }

  static bool _boolean(Object? value, String label) {
    if (value is! bool) throw FormatException('invalid_$label');
    return value;
  }

  static List<Map<String, Object?>> _rows(Object? value, String label) {
    if (value is! List) throw FormatException('invalid_$label');
    return value.map((row) {
      if (row is! Map<String, Object?>) {
        throw FormatException('invalid_${label}_row');
      }
      return row;
    }).toList(growable: false);
  }

  static void _checkTenant(Map<String, Object?> row, String tenantId) {
    if (_uuid(row['restaurant_id'], 'row_restaurant_id') != tenantId) {
      throw const FormatException('catalog_row_tenant_mismatch');
    }
  }

  static String _decimal(Object? value, int precision) {
    if (value is! String || !_decimalPattern.hasMatch(value)) {
      throw const FormatException('invalid_catalog_decimal');
    }
    final fractional = value.split('.');
    if (fractional.length > 1 && fractional.last.length > precision) {
      throw const FormatException('catalog_decimal_precision_loss');
    }
    if (!RegExp('[1-9]').hasMatch(value)) {
      throw const FormatException('catalog_decimal_not_positive');
    }
    return value;
  }

  static bool _isOne(String value) {
    final parts = value.split('.');
    return parts.first == '1' &&
        (parts.length == 1 || !RegExp('[1-9]').hasMatch(parts.last));
  }
}
