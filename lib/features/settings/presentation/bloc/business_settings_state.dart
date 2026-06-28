import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';

/// Base business settings state.
sealed class BusinessSettingsState extends Equatable {
  /// Creates a business settings state.
  const BusinessSettingsState();

  @override
  List<Object?> get props => [];
}

/// Initial business settings state.
final class BusinessSettingsInitial extends BusinessSettingsState {
  /// Creates the initial state.
  const BusinessSettingsInitial();
}

/// Business settings loading state.
final class BusinessSettingsLoading extends BusinessSettingsState {
  /// Creates a loading state.
  const BusinessSettingsLoading();
}

/// Business settings loaded state.
final class BusinessSettingsLoaded extends BusinessSettingsState {
  /// Creates a loaded state.
  const BusinessSettingsLoaded(this.settings, {this.saved = false});

  /// Current settings.
  final BusinessSettings settings;

  /// Whether this state was emitted after a successful save.
  final bool saved;

  @override
  List<Object?> get props => [settings, saved];
}

/// Business settings failure state.
final class BusinessSettingsFailure extends BusinessSettingsState {
  /// Creates a failure state.
  const BusinessSettingsFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
