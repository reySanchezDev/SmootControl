import 'package:equatable/equatable.dart';

/// Represents an application failure with a stable code.
final class AppFailure extends Equatable {
  /// Creates an application failure.
  const AppFailure({
    required this.code,
    required this.message,
    this.cause,
  });

  /// Machine-friendly failure code.
  final String code;

  /// Human-friendly failure message.
  final String message;

  /// Original error or contextual data when available.
  final Object? cause;

  @override
  List<Object?> get props => [code, message, cause];
}
