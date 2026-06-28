import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/tables/domain/repositories/i_tables_repository.dart';
import 'package:smoo_control/features/tables/presentation/bloc/tables_event.dart';
import 'package:smoo_control/features/tables/presentation/bloc/tables_state.dart';
import 'package:uuid/uuid.dart';

/// BLoC for restaurant table management.
final class TablesBloc extends Bloc<TablesEvent, TablesState> {
  /// Creates a tables BLoC.
  TablesBloc({
    required ITablesRepository repository,
    required IAuditLogRepository auditLogRepository,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _auditLogRepository = auditLogRepository,
       _uuid = uuid,
       super(const TablesInitial()) {
    on<TablesLoadRequested>(_onLoadRequested);
    on<TableSaved>(_onTableSaved);
  }

  final ITablesRepository _repository;
  final IAuditLogRepository _auditLogRepository;
  final Uuid _uuid;

  Future<void> _onLoadRequested(
    TablesLoadRequested event,
    Emitter<TablesState> emit,
  ) async {
    emit(const TablesLoading());
    final result = await _repository.getTables();
    emit(
      result.when(
        success: TablesLoaded.new,
        failure: TablesFailure.new,
      ),
    );
  }

  Future<void> _onTableSaved(
    TableSaved event,
    Emitter<TablesState> emit,
  ) async {
    emit(const TablesLoading());
    final saveResult = await _repository.saveTable(event.table);

    switch (saveResult) {
      case AppFailureResult(:final error):
        emit(TablesFailure(error));
        return;
      case AppSuccess():
        break;
    }

    await _auditLogRepository.saveEntry(
      AuditLogEntry(
        id: _uuid.v4(),
        action: 'tables.save',
        entityName: 'restaurant_tables',
        entityId: event.table.id,
        details: {
          'name': event.table.name,
          'status': event.table.status.name,
          'isActive': event.table.isActive,
        },
        occurredAt: DateTime.now(),
      ),
    );

    final loadResult = await _repository.getTables();
    emit(
      loadResult.when(
        success: TablesLoaded.new,
        failure: TablesFailure.new,
      ),
    );
  }
}
