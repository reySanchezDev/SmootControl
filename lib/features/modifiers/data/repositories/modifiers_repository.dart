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

/// Local repository for reusable POS modifiers.
final class ModifiersRepository implements IModifiersRepository {
  /// Creates a repository.
  const ModifiersRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
  }) : _syncQueueRepository = syncQueueRepository;

  final LocalModifiersDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;

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
      final saved = await _localDataSource.saveGroup(
        ModifierGroupModel.fromEntity(group),
      );
      final entity = saved.toEntity();
      await _syncQueueRepository?.enqueue(
        entityType: 'modifier_groups',
        entityId: entity.id,
        operation: SyncOperation.create,
        payload: {
          'id': entity.id,
          'name': entity.name,
          'isRequired': entity.isRequired,
          'displayOrder': entity.displayOrder,
          'isActive': entity.isActive,
        },
      );
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
      final saved = await _localDataSource.saveOption(
        ModifierOptionModel.fromEntity(option),
      );
      final entity = saved.toEntity();
      await _syncQueueRepository?.enqueue(
        entityType: 'modifier_options',
        entityId: entity.id,
        operation: SyncOperation.create,
        payload: {
          'id': entity.id,
          'groupId': entity.groupId,
          'name': entity.name,
          'priceDeltaInCents': entity.priceDeltaInCents,
          'displayOrder': entity.displayOrder,
          'isActive': entity.isActive,
          'isAvailableInPos': entity.isAvailableInPos,
        },
      );
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
}
