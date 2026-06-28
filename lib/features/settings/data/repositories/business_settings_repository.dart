import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/settings/data/datasources/local_business_settings_datasource.dart';
import 'package:smoo_control/features/settings/data/models/business_settings_model.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';
import 'package:smoo_control/features/settings/domain/repositories/i_business_settings_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';

/// Business settings repository backed by the local offline database.
final class BusinessSettingsRepository implements IBusinessSettingsRepository {
  /// Creates a business settings repository.
  const BusinessSettingsRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
  }) : _syncQueueRepository = syncQueueRepository;

  final LocalBusinessSettingsDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;

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
    BusinessSettings settings,
  ) async {
    try {
      final model = BusinessSettingsModel.fromEntity(settings);
      final saved = await _localDataSource.saveSettings(model);
      final entity = saved.toEntity();
      await _enqueueSettings(entity);

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
      payload: {
        'businessName': settings.businessName,
        'legalName': settings.legalName,
        'taxNumber': settings.taxNumber,
        'phone': settings.phone,
        'address': settings.address,
        'showCompanyInfoOnReceipts': settings.showCompanyInfoOnReceipts,
        'invoicePrefix': settings.invoicePrefix,
        'initialInvoiceNumber': settings.initialInvoiceNumber,
        'nextInvoiceNumber': settings.nextInvoiceNumber,
      },
    );
  }
}
