import 'package:equatable/equatable.dart';

/// Permission available to assign to roles.
final class AccessPermission extends Equatable {
  /// Creates an access permission.
  const AccessPermission({
    required this.code,
    required this.name,
    this.description,
  });

  /// Stable machine code.
  final String code;

  /// Visible permission name.
  final String name;

  /// Optional description.
  final String? description;

  @override
  List<Object?> get props => [code, name, description];
}
