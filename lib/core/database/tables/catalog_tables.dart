import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/tables/sync_columns.dart';

/// Local categories and subcategories used by the POS.
class LocalProductCategories extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Parent category when this row is a subcategory.
  TextColumn get parentId => text().nullable()();

  /// Visible category name.
  TextColumn get name => text()();

  /// Sorting position in POS grids.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Whether the category can be used.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local sellable products.
class LocalProducts extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Category or subcategory identifier.
  TextColumn get categoryId => text()();

  /// Visible product name.
  TextColumn get name => text()();

  /// Price in minor currency units.
  IntColumn get priceInCents => integer()();

  /// Cost in minor currency units.
  IntColumn get costInCents => integer().withDefault(const Constant(0))();

  /// Whether the product can be sold.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Whether the product is visible in the POS today.
  BoolColumn get isAvailableInPos =>
      boolean().withDefault(const Constant(true))();

  /// Whether sales should consume inventory stock.
  BoolColumn get tracksInventory =>
      boolean().withDefault(const Constant(false))();

  /// JSON configuration for POS option groups.
  TextColumn get optionGroupsJson => text().withDefault(const Constant('[]'))();

  /// JSON list of reusable modifier group ids assigned to this product.
  TextColumn get modifierGroupIdsJson =>
      text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Sales type applied to a whole POS order.
class LocalSalesTypes extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Stable code, for example dine_in or to_go.
  TextColumn get code => text()();

  /// Visible sales type name.
  TextColumn get name => text()();

  /// Sorting position in POS selectors.
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  /// Whether this sales type is selected by default in POS.
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// Whether this sales type can be selected.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Packaging item consumed by sales types, not sold directly.
class LocalPackagingItems extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Visible packaging name.
  TextColumn get name => text()();

  /// Unit cost in minor currency units.
  IntColumn get costInCents => integer().withDefault(const Constant(0))();

  /// Whether this packaging validates and consumes stock.
  BoolColumn get tracksStock => boolean().withDefault(const Constant(true))();

  /// Whether this packaging can be used by rules.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Packaging required by one product under one sales type.
class LocalProductPackagingRules extends Table with SyncColumns {
  /// Stable rule identifier.
  TextColumn get id => text()();

  /// Product sold in POS.
  TextColumn get productId => text()();

  /// Sales type that activates the rule.
  TextColumn get salesTypeId => text()();

  /// Packaging item consumed.
  TextColumn get packagingItemId => text()();

  /// Units consumed per sold product unit.
  IntColumn get quantityPerUnit => integer().withDefault(const Constant(1))();

  /// Whether this rule can be used.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Reusable modifier groups requested by the POS.
class LocalModifierGroups extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Visible group name, for example Bastimento or Guarnicion.
  TextColumn get name => text()();

  /// Whether this group must be answered in POS.
  BoolColumn get isRequired => boolean().withDefault(const Constant(true))();

  /// Sorting position in POS option dialogs.
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  /// Whether the group can be assigned and used.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Options available inside one reusable modifier group.
class LocalModifierOptions extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Parent modifier group.
  TextColumn get groupId => text()();

  /// Visible option name.
  TextColumn get name => text()();

  /// Optional price delta applied when the option is selected.
  IntColumn get priceDeltaInCents => integer().withDefault(const Constant(0))();

  /// Sorting position in POS option dialogs.
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  /// Whether the option exists in the catalog.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Whether the option is available in today's POS operation.
  BoolColumn get isAvailableInPos =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local payment methods.
class LocalPaymentMethods extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Visible method name.
  TextColumn get name => text()();

  /// Parent payment method node for nested POS payment navigation.
  TextColumn get parentId => text().nullable()();

  /// Visual group shown first in POS payment buttons.
  TextColumn get groupName => text().withDefault(const Constant('Otros'))();

  /// Optional currency code for the method.
  TextColumn get currencyCode => text().nullable()();

  /// Sorting position in POS payment buttons.
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  /// Whether this row is a final payment option.
  BoolColumn get isPaymentTarget =>
      boolean().withDefault(const Constant(true))();

  /// Whether this method affects physical cash.
  BoolColumn get affectsCashRegister =>
      boolean().withDefault(const Constant(false))();

  /// Whether a reference must be captured.
  BoolColumn get requiresReference =>
      boolean().withDefault(const Constant(false))();

  /// Whether the method is available for new sales.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
