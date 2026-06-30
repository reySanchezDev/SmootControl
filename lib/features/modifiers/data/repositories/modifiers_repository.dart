import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/modifiers/data/datasources/local_modifiers_datasource.dart';
import 'package:smoo_control/features/modifiers/data/models/modifier_group_model.dart';
import 'package:smoo_control/features/modifiers/data/models/modifier_option_model.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_catalog.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';
import 'package:smoo_control/features/modifiers/domain/repositories/i_modifiers_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

/// Local repository for reusable POS modifiers.
final class ModifiersRepository implements IModifiersRepository {
  /// Creates a repository.
  const ModifiersRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
    ISyncRemoteSender? remoteSender,
  }) : _syncQueueRepository = syncQueueRepository,
       _remoteSender = remoteSender;

  final LocalModifiersDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;
  final ISyncRemoteSender? _remoteSender;

  @override
  Future<AppResult<ModifierCatalog>> getCatalog() async {
    try {
      final groups = await _localDataSource.getGroups();
      final options = await _localDataSource.getOptions();
      return AppSuccess(
        ModifierCatalog(
          groups: groups.map((group) => group.toEntity()).toList(),
          options: options.map((option) => option.toEntity()).toList(),
        ),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'modifiers_read_failed',
          message: 'No se pudieron leer los modificadores locales.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<ModifierGroup>> saveGroup(ModifierGroup group) async {
    try {
      await _pushRemote(
        entityType: 'modifier_groups',
        entityId: group.id,
        payload: _groupPayload(group),
      );
      final saved = await _localDataSource.saveGroup(
        ModifierGroupModel.fromEntity(group),
      );
      final entity = saved.toEntity();
      if (_remoteSender == null) {
        await _syncQueueRepository?.enqueue(
          entityType: 'modifier_groups',
          entityId: entity.id,
          operation: SyncOperation.create,
          payload: _groupPayload(entity),
        );
      }
      return AppSuccess(entity);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'modifier_group_save_failed',
          message: 'No se pudo guardar el grupo modificador.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<ModifierOption>> saveOption(ModifierOption option) async {
    try {
      await _pushRemote(
        entityType: 'modifier_options',
        entityId: option.id,
        payload: _optionPayload(option),
      );
      final saved = await _localDataSource.saveOption(
        ModifierOptionModel.fromEntity(option),
      );
      final entity = saved.toEntity();
      if (_remoteSender == null) {
        await _syncQueueRepository?.enqueue(
          entityType: 'modifier_options',
          entityId: entity.id,
          operation: SyncOperation.create,
          payload: _optionPayload(entity),
        );
      }
      return AppSuccess(entity);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'modifier_option_save_failed',
          message: 'No se pudo guardar la opcion modificadora.',
          cause: error,
        ),
      );
    }
  }

  Map<String, Object?> _groupPayload(ModifierGroup group) {
    return {
      'id': group.id,
      'name': group.name,
      'isRequired': group.isRequired,
      'displayOrder': group.displayOrder,
      'isActive': group.isActive,
    };
  }

  Map<String, Object?> _optionPayload(ModifierOption option) {
    return {
      'id': option.id,
      'groupId': option.groupId,
      'name': option.name,
      'priceDeltaInCents': option.priceDeltaInCents,
      'displayOrder': option.displayOrder,
      'isActive': option.isActive,
      'isAvailableInPos': option.isAvailableInPos,
    };
  }

  Future<void> _pushRemote({
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
  }) async {
    final remoteSender = _remoteSender;
    if (remoteSender == null) return;

    final now = DateTime.now();
    await remoteSender.push(
      SyncQueueItem(
        id: 'admin-direct-$entityType-$entityId',
        entityType: entityType,
        entityId: entityId,
        operation: SyncOperation.create,
        payload: payload,
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
