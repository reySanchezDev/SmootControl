import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/users/domain/entities/app_user_profile.dart';

/// Base event for users management.
sealed class UsersEvent extends Equatable {
  /// Creates a users event.
  const UsersEvent();

  @override
  List<Object?> get props => [];
}

/// Requests loading users and roles.
final class UsersLoadRequested extends UsersEvent {
  /// Creates a load requested event.
  const UsersLoadRequested();
}

/// Saves a local user profile.
final class UserSaved extends UsersEvent {
  /// Creates a user saved event.
  const UserSaved(this.user, {this.pin});

  /// User profile to save.
  final AppUserProfile user;

  /// Optional new local access PIN.
  final String? pin;

  @override
  List<Object?> get props => [user, pin];
}
