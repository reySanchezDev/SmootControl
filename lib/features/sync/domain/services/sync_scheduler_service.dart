import 'dart:async';

import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_process_summary.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_settings_repository.dart';
import 'package:smoo_control/features/sync/domain/services/sync_queue_processor.dart';

/// Runs automatic synchronization according to local operator settings.
final class SyncSchedulerService {
  /// Creates an automatic synchronization scheduler.
  SyncSchedulerService({
    required ISyncSettingsRepository settingsRepository,
    required SyncQueueProcessor processor,
  }) : _settingsRepository = settingsRepository,
       _processor = processor;

  final ISyncSettingsRepository _settingsRepository;
  final SyncQueueProcessor _processor;

  Timer? _timer;
  bool _isRunning = false;
  bool _started = false;

  /// Starts the scheduler once.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh(runStartupSync: true);
  }

  /// Reloads settings and reprograms the periodic timer.
  Future<void> refresh({bool runStartupSync = false}) async {
    _timer?.cancel();
    _timer = null;

    final result = await _settingsRepository.getSettings();
    await result.when(
      success: (settings) async {
        if (!settings.autoSyncEnabled) return;

        _timer = Timer.periodic(
          Duration(minutes: settings.intervalMinutes),
          (_) => unawaited(runNow()),
        );

        if (runStartupSync && settings.syncOnStartup) {
          await runNow();
        }
      },
      failure: (_) async {},
    );
  }

  /// Processes the queue immediately if no other run is active.
  Future<AppResult<SyncProcessSummary>?> runNow() async {
    if (_isRunning) return null;
    _isRunning = true;
    try {
      return await _processor.processPending();
    } finally {
      _isRunning = false;
    }
  }

  /// Retries the existing FIFO queue when automatic synchronization is enabled.
  Future<void> runAutomaticallyNow() async {
    final settingsResult = await _settingsRepository.getSettings();
    if (settingsResult case AppSuccess(
      :final value,
    ) when value.autoSyncEnabled) {
      await runNow();
    }
  }

  /// Drains newly queued work when a local operation is saved.
  Future<void> runOnSaveNow() async {
    final settingsResult = await _settingsRepository.getSettings();
    if (settingsResult case AppSuccess(:final value) when value.syncOnSave) {
      await runNow();
    }
  }

  /// Stops the scheduler.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}
