import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/settings/data/models/business_settings_model.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';

/// Local datasource for business settings.
final class LocalBusinessSettingsDataSource {
  /// Creates a local business settings datasource.
  const LocalBusinessSettingsDataSource(this._database);

  static const _settingsId = 'default';

  final AppDatabase _database;

  /// Returns saved settings or default empty settings.
  Future<BusinessSettingsModel> getSettings() async {
    final row = await (_database.select(
      _database.localBusinessSettings,
    )..where((settings) => settings.id.equals(_settingsId))).getSingleOrNull();

    if (row == null) {
      return BusinessSettingsModel.fromEntity(BusinessSettings.empty);
    }

    return BusinessSettingsModel.fromLocal(row);
  }

  /// Saves local settings.
  Future<BusinessSettingsModel> saveSettings(
    BusinessSettingsModel settings,
  ) async {
    final now = DateTime.now();

    await _database
        .into(_database.localBusinessSettings)
        .insertOnConflictUpdate(
          LocalBusinessSettingsCompanion(
            id: const Value(_settingsId),
            businessName: Value(settings.businessName),
            legalName: Value(settings.legalName),
            taxNumber: Value(settings.taxNumber),
            phone: Value(settings.phone),
            address: Value(settings.address),
            showCompanyInfoOnReceipts: Value(
              settings.showCompanyInfoOnReceipts,
            ),
            invoicePrefix: Value(settings.invoicePrefix),
            initialInvoiceNumber: Value(settings.initialInvoiceNumber),
            nextInvoiceNumber: Value(settings.nextInvoiceNumber),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return settings;
  }
}
