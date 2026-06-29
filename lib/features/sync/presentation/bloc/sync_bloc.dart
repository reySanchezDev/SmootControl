import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_process_summary.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_settings_repository.dart';
import 'package:smoo_control/features/sync/domain/services/sync_queue_processor.dart';
import 'package:smoo_control/features/sync/domain/services/sync_scheduler_service.dart';
import 'package:smoo_control/features/sync/presentation/bloc/sync_event.dart';
import 'package:smoo_control/features/sync/presentation/bloc/sync_state.dart';

/// BLoC for local synchronization queue inspection.
final class SyncBloc extends Bloc<SyncEvent, SyncState> {
  /// Creates a sync BLoC.
  SyncBloc({
    required ISyncQueueRepository repository,
    required ISyncSettingsRepository settingsRepository,
    required SyncQueueProcessor processor,
    required SyncSchedulerService scheduler,
  }) : _repository = repository,
       _settingsRepository = settingsRepository,
       _processor = processor,
       _scheduler = scheduler,
       super(const SyncInitial()) {
    on<SyncQueueRequested>(_onQueueRequested);
    on<SyncProcessRequested>(_onProcessRequested);
    on<SyncSettingsSaved>(_onSettingsSaved);
  }

  final ISyncQueueRepository _repository;
  final ISyncSettingsRepository _settingsRepository;
  final SyncQueueProcessor _processor;
  final SyncSchedulerService _scheduler;

  Future<void> _onQueueRequested(
    SyncQueueRequested event,
    Emitter<SyncState> emit,
  ) async {
    await _loadQueue(emit);
  }

  Future<void> _onProcessRequested(
    SyncProcessRequested event,
    Emitter<SyncState> emit,
  ) async {
    emit(const SyncLoading());
    final processResult = await _processor.processPending();

    switch (processResult) {
      case AppFailureResult(:final error):
        emit(SyncFailure(error));
        return;
      case AppSuccess(:final value):
        await _loadQueue(emit, summary: value);
    }
  }

  Future<void> _onSettingsSaved(
    SyncSettingsSaved event,
    Emitter<SyncState> emit,
  ) async {
    emit(const SyncLoading());
    final saveResult = await _settingsRepository.saveSettings(event.settings);

    switch (saveResult) {
      case AppFailureResult(:final error):
        emit(SyncFailure(error));
        return;
      case AppSuccess():
        await _scheduler.refresh();
        await _loadQueue(emit, settingsSaved: true);
    }
  }

  Future<void> _loadQueue(
    Emitter<SyncState> emit, {
    SyncProcessSummary? summary,
    bool settingsSaved = false,
  }) async {
    emit(const SyncLoading());
    final settingsResult = await _settingsRepository.getSettings();
    switch (settingsResult) {
      case AppFailureResult(:final error):
        emit(SyncFailure(error));
        return;
      case AppSuccess(:final value):
        final result = await _repository.getPendingItems();
        emit(
          result.when(
            success: (items) => SyncLoaded(
              items: items,
              settings: value,
              lastSummary: summary,
              settingsSaved: settingsSaved,
            ),
            failure: SyncFailure.new,
          ),
        );
    }
  }
}
