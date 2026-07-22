import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/tables/sync_columns.dart';

/// Local employee catalog used by POS-only flows.
class LocalEmployees extends Table with SyncColumns {
  /// Employee identifier from Supabase.
  TextColumn get id => text()();

  /// Optional visible code.
  TextColumn get code => text().nullable()();

  /// Employee display name.
  TextColumn get fullName => text()();

  /// Optional position or role label.
  TextColumn get positionName => text().nullable()();

  /// Base salary in minor currency units.
  IntColumn get baseSalaryInCents => integer().withDefault(const Constant(0))();

  /// Whether this employee can be selected in POS.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Optional image URL/path shown by the time-clock.
  TextColumn get photoUrl => text().nullable()();

  /// Whether the employee appears in the time-clock APK.
  BoolColumn get showInTimeClock =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local operational rule cache downloaded from Supabase.
class LocalBusinessRules extends Table with SyncColumns {
  /// Stable rule key.
  TextColumn get key => text()();

  /// Boolean value for simple toggles.
  BoolColumn get boolValue => boolean().nullable()();

  /// Text value reserved for future rules.
  TextColumn get textValue => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Local salary advances registered from POS while offline.
class LocalSalaryAdvances extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Employee identifier.
  TextColumn get employeeId => text()();

  /// Optional cash register session if the rule affects cash.
  TextColumn get cashRegisterSessionId => text().nullable()();

  /// Advance amount in minor currency units.
  IntColumn get amountInCents => integer()();

  /// Whether this advance affected the POS cash drawer.
  BoolColumn get affectsCash => boolean().withDefault(const Constant(false))();

  /// Optional note.
  TextColumn get note => text().nullable()();

  /// User that registered the advance.
  TextColumn get createdBy => text()();

  /// Date when the money was delivered.
  DateTimeColumn get deliveredAt => dateTime().nullable()();

  /// Pending, synced, voided or applied.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local attendance entries created by the time-clock APK.
class LocalAttendanceEntries extends Table with SyncColumns {
  /// Local attendance identifier.
  TextColumn get id => text()();

  /// Employee identifier.
  TextColumn get employeeId => text()();

  /// Work day used for payroll grouping.
  DateTimeColumn get workDate => dateTime()();

  /// Clock-in timestamp.
  DateTimeColumn get clockInAt => dateTime().nullable()();

  /// Clock-out timestamp.
  DateTimeColumn get clockOutAt => dateTime().nullable()();

  /// open, closed or voided.
  TextColumn get status => text().withDefault(const Constant('open'))();

  /// Source of the record.
  TextColumn get source => text().withDefault(const Constant('time_clock'))();

  /// Verification method used in V1.
  TextColumn get verificationMethod =>
      text().withDefault(const Constant('photo_tap'))();

  /// Optional note.
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
