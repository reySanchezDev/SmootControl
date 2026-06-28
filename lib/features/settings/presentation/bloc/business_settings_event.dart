import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';

/// Base event for business settings state management.
sealed class BusinessSettingsEvent extends Equatable {
  /// Creates a business settings event.
  const BusinessSettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Loads business settings.
final class BusinessSettingsLoadRequested extends BusinessSettingsEvent {
  /// Creates a load event.
  const BusinessSettingsLoadRequested();
}

/// Saves business settings.
final class BusinessSettingsSaved extends BusinessSettingsEvent {
  /// Creates a save event.
  const BusinessSettingsSaved(this.settings);

  /// Settings to persist.
  final BusinessSettings settings;

  @override
  List<Object?> get props => [settings];
}
