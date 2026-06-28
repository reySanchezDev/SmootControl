import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';

/// Base state for roles management.
sealed class RolesState extends Equatable {
  /// Creates a roles state.
  const RolesState();

  @override
  List<Object?> get props => [];
}

/// Initial roles state.
final class RolesInitial extends RolesState {
  /// Creates initial state.
  const RolesInitial();
}

/// Loading roles state.
final class RolesLoading extends RolesState {
  /// Creates loading state.
  const RolesLoading();
}

/// Loaded roles state.
final class RolesLoaded extends RolesState {
  /// Creates loaded state.
  const RolesLoaded({
    required this.roles,
    required this.permissions,
    required this.permissionCodesByRole,
  });

  /// Roles.
  final List<AccessRole> roles;

  /// Permission catalog.
  final List<AccessPermission> permissions;

  /// Permission codes by role id.
  final Map<String, List<String>> permissionCodesByRole;

  @override
  List<Object?> get props => [roles, permissions, permissionCodesByRole];
}

/// Failed roles state.
final class RolesFailure extends RolesState {
  /// Creates failed state.
  const RolesFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
