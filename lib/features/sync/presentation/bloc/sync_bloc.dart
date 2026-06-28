import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_process_summary.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/services/sync_queue_processor.dart';
import 'package:smoo_control/features/sync/presentation/bloc/sync_event.dart';
import 'package:smoo_control/features/sync/presentation/bloc/sync_state.dart';

/// BLoC for local synchronization queue inspection.
final class SyncBloc extends Bloc<SyncEvent, SyncState> {
  /// Creates a sync BLoC.
  SyncBloc({
    required ISyncQueueRepository repository,
    required SyncQueueProcessor processor,
  }) : _repository = repository,
       _processor = processor,
       super(const SyncInitial()) {
    on<SyncQueueRequested>(_onQueueRequested);
    on<SyncProcessRequested>(_onProcessRequested);
  }

  final ISyncQueueRepository _repository;
  final SyncQueueProcessor _processor;

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

  Future<void> _loadQueue(
    Emitter<SyncState> emit, {
    SyncProcessSummary? summary,
  }) async {
    emit(const SyncLoading());
    final result = await _repository.getPendingItems();
    emit(
      result.when(
        success: (items) => SyncLoaded(items: items, lastSummary: summary),
        failure: SyncFailure.new,
      ),
    );
  }
}
