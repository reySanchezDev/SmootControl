/// Result of a manual remote-to-local catalog sync.
final class CatalogPullSummary {
  /// Creates a pull summary.
  const CatalogPullSummary({
    required this.businessSettings,
    required this.categories,
    required this.expenseCategories,
    required this.exchangeRates,
    required this.modifierGroups,
    required this.modifierOptions,
    required this.paymentMethods,
    required this.permissions,
    required this.products,
    required this.rolePermissions,
    required this.roles,
    required this.tables,
    required this.users,
  });

  /// Creates an empty pull summary.
  const CatalogPullSummary.empty()
    : businessSettings = 0,
      categories = 0,
      expenseCategories = 0,
      exchangeRates = 0,
      modifierGroups = 0,
      modifierOptions = 0,
      paymentMethods = 0,
      permissions = 0,
      products = 0,
      rolePermissions = 0,
      roles = 0,
      tables = 0,
      users = 0;

  /// Business settings rows updated locally.
  final int businessSettings;

  /// Product categories updated locally.
  final int categories;

  /// Expense categories updated locally.
  final int expenseCategories;

  /// Exchange rates updated locally.
  final int exchangeRates;

  /// Modifier groups updated locally.
  final int modifierGroups;

  /// Modifier options updated locally.
  final int modifierOptions;

  /// Payment methods updated locally.
  final int paymentMethods;

  /// Permission catalog rows updated locally.
  final int permissions;

  /// Products updated locally.
  final int products;

  /// Role permission assignments updated locally.
  final int rolePermissions;

  /// Access roles updated locally.
  final int roles;

  /// Restaurant tables updated locally.
  final int tables;

  /// User profiles updated locally.
  final int users;

  /// Total records applied to the local database.
  int get total {
    return businessSettings +
        categories +
        expenseCategories +
        exchangeRates +
        modifierGroups +
        modifierOptions +
        paymentMethods +
        permissions +
        products +
        rolePermissions +
        roles +
        tables +
        users;
  }

  /// Missing minimum data required to operate the POS after a full restore.
  List<String> get missingPosRequirements {
    final missing = <String>[];
    if (businessSettings == 0) missing.add('configuracion del negocio');
    if (users == 0) missing.add('usuarios POS');
    if (roles == 0) missing.add('roles');
    if (permissions == 0) missing.add('permisos');
    if (rolePermissions == 0) missing.add('permisos asignados a roles');
    if (categories == 0) missing.add('categorias de productos');
    if (products == 0) missing.add('productos');
    if (paymentMethods == 0) missing.add('metodos de pago');
    if (tables == 0) missing.add('mesas');
    if (exchangeRates == 0) missing.add('tasas de cambio');
    return missing;
  }

  /// Whether a full restore downloaded enough data to start selling.
  bool get isReadyForPos => missingPosRequirements.isEmpty;
}
