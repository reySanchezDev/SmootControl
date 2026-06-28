import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';

/// Base event for roles management.
sealed class RolesEvent extends Equatable {
  /// Creates a roles event.
  const RolesEvent();

  @override
  List<Object?> get props => [];
}

/// Requests loading roles and permissions.
final class RolesLoadRequested extends RolesEvent {
  /// Creates a load requested event.
  const RolesLoadRequested();
}

/// Saves a role and its permission assignments.
final class RoleSaved extends RolesEvent {
  /// Creates a role saved event.
  const RoleSaved({
    required this.role,
    required this.permissionCodes,
  });

  /// Role to save.
  final AccessRole role;

  /// Assigned permission codes.
  final List<String> permissionCodes;

  @override
  List<Object?> get props => [role, permissionCodes];
}
