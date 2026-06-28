import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/tables/sync_columns.dart';

/// Local business settings for receipts, PDFs, and invoice numbering.
class LocalBusinessSettings extends Table with SyncColumns {
  /// Single settings row identifier managed by the system.
  TextColumn get id => text()();

  /// Public business name printed in receipts.
  TextColumn get businessName => text()();

  /// Legal business name, when different from the public name.
  TextColumn get legalName => text().nullable()();

  /// Tax identifier shown on generated PDFs when configured.
  TextColumn get taxNumber => text().nullable()();

  /// Business phone shown on generated PDFs when configured.
  TextColumn get phone => text().nullable()();

  /// Business address shown on generated PDFs when configured.
  TextColumn get address => text().nullable()();

  /// Whether company data should be printed on generated PDFs.
  BoolColumn get showCompanyInfoOnReceipts =>
      boolean().withDefault(const Constant(true))();

  /// Prefix used for local invoice numbers.
  TextColumn get invoicePrefix => text().withDefault(const Constant('F'))();

  /// First invoice number configured by the administrator.
  IntColumn get initialInvoiceNumber => integer().withDefault(
    const Constant(1),
  )();

  /// Next invoice number to be issued by the system.
  IntColumn get nextInvoiceNumber => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
