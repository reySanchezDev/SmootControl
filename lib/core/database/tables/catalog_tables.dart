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

  /// JSON configuration for POS option groups.
  TextColumn get optionGroupsJson => text().withDefault(const Constant('[]'))();

  /// JSON list of reusable modifier group ids assigned to this product.
  TextColumn get modifierGroupIdsJson =>
      text().withDefault(const Constant('[]'))();

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
