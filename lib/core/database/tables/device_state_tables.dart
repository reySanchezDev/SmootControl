import 'package:drift/drift.dart';

/// Local state for a tablet initialized from the central Supabase database.
class LocalDeviceState extends Table {
  /// Single state row identifier managed by the system.
  TextColumn get id => text().withDefault(const Constant('default'))();

  /// Stable identifier generated for this local installation.
  TextColumn get deviceId => text()();

  /// Restaurant restored into this device.
  TextColumn get restaurantId => text()();

  /// User that initialized the device.
  TextColumn get initializedByUserId => text()();

  /// Time when the device was initialized.
  DateTimeColumn get initializedAt => dateTime()();

  /// Last full restore timestamp.
  DateTimeColumn get lastFullRestoreAt => dateTime()();

  /// Last restore status.
  TextColumn get lastRestoreStatus => text()();

  /// Last restore error, if any.
  TextColumn get lastRestoreError => text().nullable()();

  /// Remote device credential id used by POS sync.
  TextColumn get syncDeviceId => text().nullable()();

  /// Remote device secret used by POS sync. This is generated per device.
  TextColumn get syncDeviceSecret => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
