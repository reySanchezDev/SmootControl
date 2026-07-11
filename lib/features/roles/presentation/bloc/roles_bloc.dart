import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/roles/domain/repositories/i_roles_repository.dart';
import 'package:smoo_control/features/roles/domain/services/access_seed_service.dart';
import 'package:smoo_control/features/roles/presentation/bloc/roles_event.dart';
import 'package:smoo_control/features/roles/presentation/bloc/roles_state.dart';
import 'package:uuid/uuid.dart';

/// BLoC for roles and permissions.
final class RolesBloc extends Bloc<RolesEvent, RolesState> {
  /// Creates a roles BLoC.
  RolesBloc({
    required IRolesRepository repository,
    required AccessSeedService seedService,
    required IAuditLogRepository auditLogRepository,
    bool seedDefaults = true,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _seedService = seedService,
       _auditLogRepository = auditLogRepository,
       _seedDefaults = seedDefaults,
       _uuid = uuid,
       super(const RolesInitial()) {
    on<RolesLoadRequested>(_onLoadRequested);
    on<RoleSaved>(_onRoleSaved);
  }

  final IRolesRepository _repository;
  final AccessSeedService _seedService;
  final IAuditLogRepository _auditLogRepository;
  final bool _seedDefaults;
  final Uuid _uuid;

  Future<void> _onLoadRequested(
    RolesLoadRequested event,
    Emitter<RolesState> emit,
  ) async {
    emit(const RolesLoading());
    await _load(emit);
  }

  Future<void> _onRoleSaved(
    RoleSaved event,
    Emitter<RolesState> emit,
  ) async {
    emit(const RolesLoading());
    final saveResult = await _repository.saveRole(event.role);
    switch (saveResult) {
      case AppFailureResult(:final error):
        emit(RolesFailure(error));
        return;
      case AppSuccess():
        break;
    }

    final permissionsResult = await _repository.setRolePermissions(
      roleId: event.role.id,
      permissionCodes: event.permissionCodes,
    );
    switch (permissionsResult) {
      case AppFailureResult(:final error):
        emit(RolesFailure(error));
        return;
      case AppSuccess():
        await _auditLogRepository.saveEntry(
          AuditLogEntry(
            id: _uuid.v4(),
            action: 'roles.save',
            entityName: 'roles',
            entityId: event.role.id,
            details: {
              'name': event.role.name,
              'permissionCount': event.permissionCodes.length,
            },
            occurredAt: DateTime.now(),
          ),
        );
        await _load(emit);
    }
  }

  Future<void> _load(Emitter<RolesState> emit) async {
    if (_seedDefaults) {
      final seedResult = await _seedService.ensureSeeded();
      if (seedResult case AppFailureResult(:final error)) {
        emit(RolesFailure(error));
        return;
      }
    }

    final rolesResult = await _repository.getRoles();
    final permissionsResult = await _repository.getPermissions();

    switch ((rolesResult, permissionsResult)) {
      case (
        AppSuccess<List<AccessRole>>(:final value),
        AppSuccess(value: final permissions),
      ):
        final codesByRole = <String, List<String>>{};
        for (final role in value) {
          final codesResult = await _repository.getPermissionCodesForRole(
            role.id,
          );
          codesResult.when(
            success: (codes) => codesByRole[role.id] = codes,
            failure: (_) => codesByRole[role.id] = const [],
          );
        }
        emit(
          RolesLoaded(
            roles: value,
            permissions: permissions,
            permissionCodesByRole: codesByRole,
          ),
        );
      case (AppFailureResult(:final error), _):
        emit(RolesFailure(error));
      case (_, AppFailureResult(:final error)):
        emit(RolesFailure(error));
    }
  }
}
