import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/users/domain/entities/app_user_profile.dart';

/// Base state for users management.
sealed class UsersState extends Equatable {
  /// Creates a users state.
  const UsersState();

  @override
  List<Object?> get props => [];
}

/// Initial users state.
final class UsersInitial extends UsersState {
  /// Creates initial state.
  const UsersInitial();
}

/// Loading users state.
final class UsersLoading extends UsersState {
  /// Creates loading state.
  const UsersLoading();
}

/// Loaded users state.
final class UsersLoaded extends UsersState {
  /// Creates loaded state.
  const UsersLoaded({
    required this.users,
    required this.roles,
  });

  /// Local users.
  final List<AppUserProfile> users;

  /// Assignable roles.
  final List<AccessRole> roles;

  @override
  List<Object?> get props => [users, roles];
}

/// Failed users state.
final class UsersFailure extends UsersState {
  /// Creates failed state.
  const UsersFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
