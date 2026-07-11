import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/modifiers/domain/repositories/i_modifiers_repository.dart';
import 'package:smoo_control/features/modifiers/presentation/bloc/modifiers_event.dart';
import 'package:smoo_control/features/modifiers/presentation/bloc/modifiers_state.dart';
import 'package:uuid/uuid.dart';

/// BLoC for reusable POS modifiers.
final class ModifiersBloc extends Bloc<ModifiersEvent, ModifiersState> {
  /// Creates a modifiers BLoC.
  ModifiersBloc({
    required IModifiersRepository repository,
    required IAuditLogRepository auditLogRepository,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _auditLogRepository = auditLogRepository,
       _uuid = uuid,
       super(const ModifiersInitial()) {
    on<ModifiersLoadRequested>(_onLoadRequested);
    on<ModifierGroupSaved>(_onGroupSaved);
    on<ModifierOptionSaved>(_onOptionSaved);
  }

  final IModifiersRepository _repository;
  final IAuditLogRepository _auditLogRepository;
  final Uuid _uuid;

  Future<void> _onLoadRequested(
    ModifiersLoadRequested event,
    Emitter<ModifiersState> emit,
  ) async {
    emit(const ModifiersLoading());
    await _reload(emit);
  }

  Future<void> _onGroupSaved(
    ModifierGroupSaved event,
    Emitter<ModifiersState> emit,
  ) async {
    emit(const ModifiersLoading());
    final saveResult = await _repository.saveGroup(event.group);
    if (saveResult case AppFailureResult(:final error)) {
      emit(ModifiersFailure(error));
      return;
    }

    await _auditLogRepository.saveEntry(
      AuditLogEntry(
        id: _uuid.v4(),
        action: 'modifiers.group.save',
        entityName: 'modifier_groups',
        entityId: event.group.id,
        details: {
          'name': event.group.name,
          'isActive': event.group.isActive,
        },
        occurredAt: DateTime.now(),
      ),
    );
    await _reload(emit);
  }

  Future<void> _onOptionSaved(
    ModifierOptionSaved event,
    Emitter<ModifiersState> emit,
  ) async {
    emit(const ModifiersLoading());
    final saveResult = await _repository.saveOption(event.option);
    if (saveResult case AppFailureResult(:final error)) {
      emit(ModifiersFailure(error));
      return;
    }

    await _auditLogRepository.saveEntry(
      AuditLogEntry(
        id: _uuid.v4(),
        action: 'modifiers.option.save',
        entityName: 'modifier_options',
        entityId: event.option.id,
        details: {
          'name': event.option.name,
          'groupId': event.option.groupId,
          'isAvailableInPos': event.option.isAvailableInPos,
        },
        occurredAt: DateTime.now(),
      ),
    );
    await _reload(emit);
  }

  Future<void> _reload(Emitter<ModifiersState> emit) async {
    final result = await _repository.getCatalog();
    emit(
      result.when(
        success: ModifiersLoaded.new,
        failure: ModifiersFailure.new,
      ),
    );
  }
}
