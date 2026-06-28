import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/roles/domain/repositories/i_roles_repository.dart';
import 'package:smoo_control/features/roles/domain/services/access_seed_service.dart';
import 'package:smoo_control/features/users/domain/entities/app_user_profile.dart';
import 'package:smoo_control/features/users/domain/repositories/i_users_repository.dart';
import 'package:smoo_control/features/users/presentation/bloc/users_event.dart';
import 'package:smoo_control/features/users/presentation/bloc/users_state.dart';
import 'package:uuid/uuid.dart';

/// BLoC for user management.
final class UsersBloc extends Bloc<UsersEvent, UsersState> {
  /// Creates a users BLoC.
  UsersBloc({
    required IUsersRepository usersRepository,
    required IRolesRepository rolesRepository,
    required AccessSeedService seedService,
    required IAuditLogRepository auditLogRepository,
    Uuid uuid = const Uuid(),
  }) : _usersRepository = usersRepository,
       _rolesRepository = rolesRepository,
       _seedService = seedService,
       _auditLogRepository = auditLogRepository,
       _uuid = uuid,
       super(const UsersInitial()) {
    on<UsersLoadRequested>(_onLoadRequested);
    on<UserSaved>(_onUserSaved);
  }

  final IUsersRepository _usersRepository;
  final IRolesRepository _rolesRepository;
  final AccessSeedService _seedService;
  final IAuditLogRepository _auditLogRepository;
  final Uuid _uuid;

  Future<void> _onLoadRequested(
    UsersLoadRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(const UsersLoading());
    await _load(emit);
  }

  Future<void> _onUserSaved(
    UserSaved event,
    Emitter<UsersState> emit,
  ) async {
    emit(const UsersLoading());
    final saveResult = await _usersRepository.saveUser(
      event.user,
      pin: event.pin,
    );
    switch (saveResult) {
      case AppFailureResult(:final error):
        emit(UsersFailure(error));
        return;
      case AppSuccess():
        await _auditLogRepository.saveEntry(
          AuditLogEntry(
            id: _uuid.v4(),
            action: 'users.save',
            entityName: 'users',
            entityId: event.user.id,
            details: {
              'email': event.user.email,
              'roleId': event.user.roleId,
            },
            occurredAt: DateTime.now(),
          ),
        );
        await _load(emit);
    }
  }

  Future<void> _load(Emitter<UsersState> emit) async {
    final seedResult = await _seedService.ensureSeeded();
    if (seedResult case AppFailureResult(:final error)) {
      emit(UsersFailure(error));
      return;
    }

    final usersResult = await _usersRepository.getUsers();
    final rolesResult = await _rolesRepository.getRoles();

    switch ((usersResult, rolesResult)) {
      case (
        AppSuccess<List<AppUserProfile>>(:final value),
        AppSuccess<List<AccessRole>>(value: final roles),
      ):
        emit(UsersLoaded(users: value, roles: roles));
      case (AppFailureResult(:final error), _):
        emit(UsersFailure(error));
      case (_, AppFailureResult(:final error)):
        emit(UsersFailure(error));
    }
  }
}
