import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/settings/domain/repositories/i_business_settings_repository.dart';
import 'package:smoo_control/features/settings/presentation/bloc/business_settings_event.dart';
import 'package:smoo_control/features/settings/presentation/bloc/business_settings_state.dart';
import 'package:smoo_control/features/sync/domain/services/admin_data_refresh_service.dart';
import 'package:uuid/uuid.dart';

/// BLoC for business settings management.
final class BusinessSettingsBloc
    extends Bloc<BusinessSettingsEvent, BusinessSettingsState> {
  /// Creates a business settings BLoC.
  BusinessSettingsBloc({
    required IBusinessSettingsRepository repository,
    required IAuditLogRepository auditLogRepository,
    AdminDataRefreshService? remoteRefreshService,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _auditLogRepository = auditLogRepository,
       _remoteRefreshService = remoteRefreshService,
       _uuid = uuid,
       super(const BusinessSettingsInitial()) {
    on<BusinessSettingsLoadRequested>(_onLoadRequested);
    on<BusinessSettingsSaved>(_onSettingsSaved);
  }

  final IBusinessSettingsRepository _repository;
  final IAuditLogRepository _auditLogRepository;
  final AdminDataRefreshService? _remoteRefreshService;
  final Uuid _uuid;

  Future<void> _onLoadRequested(
    BusinessSettingsLoadRequested event,
    Emitter<BusinessSettingsState> emit,
  ) async {
    emit(const BusinessSettingsLoading());
    if (!await _refreshRemoteCache(emit)) return;
    final result = await _repository.getSettings();
    emit(
      result.when(
        success: BusinessSettingsLoaded.new,
        failure: BusinessSettingsFailure.new,
      ),
    );
  }

  Future<void> _onSettingsSaved(
    BusinessSettingsSaved event,
    Emitter<BusinessSettingsState> emit,
  ) async {
    emit(const BusinessSettingsLoading());
    final saveResult = await _repository.saveSettings(event.settings);

    switch (saveResult) {
      case AppFailureResult(:final error):
        emit(BusinessSettingsFailure(error));
      case AppSuccess(:final value):
        await _auditLogRepository.saveEntry(
          AuditLogEntry(
            id: _uuid.v4(),
            action: 'settings.save',
            entityName: 'business_settings',
            details: {
              'businessName': value.businessName,
              'invoicePrefix': value.invoicePrefix,
            },
            occurredAt: DateTime.now(),
          ),
        );
        emit(BusinessSettingsLoaded(value, saved: true));
    }
  }

  Future<bool> _refreshRemoteCache(
    Emitter<BusinessSettingsState> emit,
  ) async {
    final result = await _remoteRefreshService?.refreshBusinessSettings();
    if (result case AppFailureResult(:final error)) {
      emit(BusinessSettingsFailure(error));
      return false;
    }
    return true;
  }
}
