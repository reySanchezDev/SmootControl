/// Technical type of a canonical article, independently of its labels.
enum CanonicalItemType {
  /// Physical stock movement enabled.
  inventory('Con inventario'),

  /// Purchasable or sellable without physical stock movement.
  nonInventory('Sin inventario'),

  /// Non-physical service.
  service('Servicio')
  ;

  const CanonicalItemType(this.label);

  /// Human-facing label.
  final String label;

  /// Database enum identifier.
  String get databaseValue => switch (this) {
    inventory => 'inventory',
    nonInventory => 'non_inventory',
    service => 'service',
  };

  /// Parses the database value without guessing based on article names.
  static CanonicalItemType parse(Object? value) => switch (value) {
    'inventory' => inventory,
    'non_inventory' => nonInventory,
    'service' => service,
    _ => throw FormatException('Tipo de artículo desconocido: $value'),
  };
}

/// Business role of an article, independent from stock behavior.
enum CanonicalItemClass {
  /// Sellable finished product.
  saleProduct('Producto', 'sale_product'),

  /// Ingredient or raw material.
  rawMaterial('Materia prima', 'raw_material'),

  /// Packaging consumed by an operation or sale.
  packaging('Empaque', 'packaging'),

  /// Non-stock service.
  service('Servicio', 'service')
  ;

  const CanonicalItemClass(this.label, this.databaseValue);

  /// Roles users may assign while creating an article.
  static List<CanonicalItemClass> get selectableValues => values
      .where((itemClass) => itemClass != CanonicalItemClass.service)
      .toList(growable: false);

  /// Human-facing label.
  final String label;

  /// Database identifier.
  final String databaseValue;

  /// Parses a database identifier.
  static CanonicalItemClass parse(Object? value) {
    if (value == null) return CanonicalItemClass.saleProduct;
    return values.firstWhere(
      (item) => item.databaseValue == value,
      orElse: () =>
          throw FormatException('Clase de artículo desconocida: $value'),
    );
  }
}

/// Classification that can be assigned to multiple canonical articles.
final class CanonicalClassification {
  /// Creates a classification.
  const CanonicalClassification({
    required this.id,
    required this.name,
    required this.code,
  });

  /// Stable identifier.
  final String id;

  /// Label.
  final String name;

  /// Human-readable code.
  final String code;
}

/// Article identity is always canonical; packaging is only a classification.
final class CanonicalItem {
  /// Creates a canonical article.
  const CanonicalItem({
    required this.code,
    required this.name,
    required this.type,
    required this.baseUnitId,
    this.itemClass = CanonicalItemClass.saleProduct,
    this.id,
    this.commercialCode,
    this.categoryId,
    this.cost = 0,
    this.price = 0,
    this.canSell = false,
    this.canPurchase = false,
    this.visibleInPos = false,
    this.usesRecipe = false,
    this.sendToKitchen = false,
    this.isActive = true,
    this.classificationIds = const [],
  });

  /// Parses an RLS-scoped Supabase response.
  factory CanonicalItem.fromRow(
    Map<String, Object?> row, {
    List<String> classificationIds = const [],
  }) {
    return CanonicalItem(
      id: row['id']?.toString(),
      commercialCode: int.tryParse(row['commercial_code']?.toString() ?? ''),
      categoryId: row['category_id']?.toString(),
      code: row['code']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      type: CanonicalItemType.parse(row['item_type']),
      itemClass: CanonicalItemClass.parse(row['item_class']),
      baseUnitId: row['base_unit_id']?.toString() ?? '',
      cost: double.tryParse(row['base_unit_cost'].toString()) ?? 0,
      price: double.tryParse(row['base_unit_price'].toString()) ?? 0,
      canSell: row['can_sell'] == true,
      canPurchase: row['can_purchase'] == true,
      visibleInPos: row['visible_in_pos'] == true,
      usesRecipe: row['uses_recipe'] == true,
      sendToKitchen: row['send_to_kitchen'] == true,
      isActive: row['is_active'] != false,
      classificationIds: classificationIds,
    );
  }

  /// UUID assigned by PostgreSQL, not by the user.
  final String? id;

  /// Product category assigned to this article.
  final String? categoryId;

  /// User-facing numeric code, unique within the restaurant.
  final int? commercialCode;

  /// Unique business code within the restaurant.
  final String code;

  /// Article description.
  final String name;

  /// Technical movement classification.
  final CanonicalItemType type;

  /// Business role shown and edited by the owner.
  final CanonicalItemClass itemClass;

  /// Existing measurement unit UUID.
  final String baseUnitId;

  /// Base-unit purchase cost.
  final double cost;

  /// Base-unit sale price.
  final double price;

  /// Whether it can be offered for sale.
  final bool canSell;

  /// Whether it can be purchased.
  final bool canPurchase;

  /// Whether it is visible to cashiers.
  final bool visibleInPos;

  /// Whether its recipe can consume components.
  final bool usesRecipe;

  /// Whether a kitchen order should be produced.
  final bool sendToKitchen;

  /// Whether it may be used for new operations.
  final bool isActive;

  /// Independent functional classification IDs.
  final List<String> classificationIds;

  /// Inventory tracking is a projection of [type], never an independent flag.
  bool get tracksInventory => type == CanonicalItemType.inventory;

  /// The trusted RPC, not direct table DML, performs every update.
  Map<String, Object?> toPayload() => {
    if (id != null) 'id': id,
    'category_id': categoryId,
    'code': code.trim(),
    'name': name.trim(),
    'item_type': type.databaseValue,
    'item_class': itemClass.databaseValue,
    'base_unit_id': baseUnitId,
    'base_unit_cost': cost,
    'base_unit_price': price,
    'can_sell': canSell,
    'can_purchase': canPurchase,
    'visible_in_pos': visibleInPos,
    'uses_recipe': usesRecipe,
    'send_to_kitchen': sendToKitchen,
    'is_active': isActive,
    'classification_ids': classificationIds,
  };
}
