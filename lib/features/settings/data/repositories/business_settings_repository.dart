import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/settings/data/datasources/local_business_settings_datasource.dart';
import 'package:smoo_control/features/settings/data/models/business_settings_model.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';
import 'package:smoo_control/features/settings/domain/repositories/i_business_settings_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

/// Business settings repository backed by the local offline database.
final class BusinessSettingsRepository implements IBusinessSettingsRepository {
  /// Creates a business settings repository.
  const BusinessSettingsRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
    ISyncRemoteSender? remoteSender,
  }) : _syncQueueRepository = syncQueueRepository,
       _remoteSender = remoteSender;

  final LocalBusinessSettingsDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;
  final ISyncRemoteSender? _remoteSender;

  @override
  Future<AppResult<BusinessSettings>> getSettings() async {
    try {
      final settings = await _localDataSource.getSettings();
      return AppSuccess(settings.toEntity());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'business_settings_read_failed',
          message: 'No se pudo leer la configuracion del negocio.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<BusinessSettings>> saveSettings(
    BusinessSettings settings, {
    bool syncRemote = true,
  }) async {
    try {
      final model = BusinessSettingsModel.fromEntity(settings);
      if (syncRemote) {
        await _pushSettingsRemote(settings);
      }
      final saved = await _localDataSource.saveSettings(model);
      final entity = saved.toEntity();
      if (syncRemote && _remoteSender == null) {
        await _enqueueSettings(entity);
      }

      return AppSuccess(entity);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'business_settings_save_failed',
          message: 'No se pudo guardar la configuracion del negocio.',
          cause: error,
        ),
      );
    }
  }

  Future<void> _enqueueSettings(BusinessSettings settings) async {
    await _syncQueueRepository?.enqueue(
      entityType: 'business_settings',
      entityId: 'default',
      operation: SyncOperation.update,
      payload: _settingsPayload(settings),
    );
  }

  Future<void> _pushSettingsRemote(BusinessSettings settings) async {
    final remoteSender = _remoteSender;
    if (remoteSender == null) return;

    final now = DateTime.now();
    await remoteSender.push(
      SyncQueueItem(
        id: 'admin-direct-business_settings-default',
        entityType: 'business_settings',
        entityId: 'default',
        operation: SyncOperation.update,
        payload: _settingsPayload(settings),
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Map<String, Object?> _settingsPayload(BusinessSettings settings) {
    return {
      'businessName': settings.businessName,
      'legalName': settings.legalName,
      'taxNumber': settings.taxNumber,
      'phone': settings.phone,
      'address': settings.address,
      'showCompanyInfoOnReceipts': settings.showCompanyInfoOnReceipts,
      'invoicePrefix': settings.invoicePrefix,
      'initialInvoiceNumber': settings.initialInvoiceNumber,
      'nextInvoiceNumber': settings.nextInvoiceNumber,
    };
  }
}
