import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';

/// Contract for business settings persistence.
abstract interface class IBusinessSettingsRepository {
  /// Returns the current business settings.
  Future<AppResult<BusinessSettings>> getSettings();

  /// Saves business settings.
  Future<AppResult<BusinessSettings>> saveSettings(BusinessSettings settings);
}
