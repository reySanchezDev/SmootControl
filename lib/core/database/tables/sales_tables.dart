import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/tables/sync_columns.dart';

/// Local completed or voided sales.
class LocalSales extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Sequential invoice or receipt number.
  TextColumn get invoiceNumber => text()();

  /// sale or staff_consumption.
  TextColumn get saleKind => text().withDefault(const Constant('sale'))();

  /// Employee linked to internal staff consumption.
  TextColumn get employeeId => text().nullable()();

  /// Remote internal receipt sequence for staff consumption.
  IntColumn get internalReceiptNumber => integer().nullable()();

  /// Payroll run that consumed this internal sale.
  TextColumn get payrollRunId => text().nullable()();

  /// Original table identifier, when applicable.
  TextColumn get tableId => text().nullable()();

  /// Split account identifier, when applicable.
  TextColumn get tableAccountId => text().nullable()();

  /// Daily cash register session identifier, when applicable.
  TextColumn get cashRegisterSessionId => text().nullable()();

  /// Payment method identifier.
  TextColumn get paymentMethodId => text()();

  /// Sales type identifier selected for the order.
  TextColumn get salesTypeId => text().nullable()();

  /// Historical sales type name selected for the order.
  TextColumn get salesTypeName => text().nullable()();

  /// Captured payment reference.
  TextColumn get paymentReference => text().nullable()();

  /// completed or voided.
  TextColumn get status => text().withDefault(const Constant('completed'))();

  /// Sale subtotal in minor currency units.
  IntColumn get subtotalInCents => integer()();

  /// Sale total in minor currency units.
  IntColumn get totalInCents => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local sale details with historical product data.
class LocalSaleItems extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Sale identifier.
  TextColumn get saleId => text().nullable()();

  /// Table identifier before invoicing.
  TextColumn get tableId => text().nullable()();

  /// Split account identifier before invoicing.
  TextColumn get tableAccountId => text().nullable()();

  /// Product identifier.
  TextColumn get productId => text()();

  /// Historical product name.
  TextColumn get productName => text()();

  /// Historical category name.
  TextColumn get categoryName => text()();

  /// Historical selected options, for example Acompanamiento: Tajadas.
  TextColumn get selectedOptionsLabel => text().nullable()();

  /// Quantity sold.
  IntColumn get quantity => integer()();

  /// Unit price in minor currency units.
  IntColumn get unitPriceInCents => integer()();

  /// Unit cost in minor currency units.
  IntColumn get unitCostInCents => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local auditable sale voids.
class LocalSaleVoids extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Voided sale identifier.
  TextColumn get saleId => text()();

  /// Void reason.
  TextColumn get reason => text()();

  /// User identifier that voided the sale.
  TextColumn get voidedBy => text()();

  /// Void timestamp.
  DateTimeColumn get voidedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
