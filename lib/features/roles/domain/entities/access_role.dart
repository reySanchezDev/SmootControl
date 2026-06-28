import 'package:equatable/equatable.dart';

/// Role that groups permissions for app users.
final class AccessRole extends Equatable {
  /// Creates an access role.
  const AccessRole({
    required this.id,
    required this.name,
    required this.isSystem,
    required this.isActive,
    this.description,
  });

  /// Local role identifier.
  final String id;

  /// Visible role name.
  final String name;

  /// Optional description.
  final String? description;

  /// Whether this role is protected by the system.
  final bool isSystem;

  /// Whether this role can be assigned.
  final bool isActive;

  @override
  List<Object?> get props => [id, name, description, isSystem, isActive];
}
