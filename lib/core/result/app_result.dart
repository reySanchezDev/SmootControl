import 'package:smoo_control/core/result/app_failure.dart';

/// Base result type used by repositories and domain services.
sealed class AppResult<T> {
  /// Creates a result.
  const AppResult();

  /// Returns true when the result is successful.
  bool get isSuccess => this is AppSuccess<T>;

  /// Returns true when the result is a failure.
  bool get isFailure => this is AppFailureResult<T>;

  /// Maps both result branches to a single value.
  R when<R>({
    required R Function(T value) success,
    required R Function(AppFailure failure) failure,
  }) {
    return switch (this) {
      AppSuccess<T>(:final value) => success(value),
      AppFailureResult<T>(:final error) => failure(error),
    };
  }
}

/// Successful operation result.
final class AppSuccess<T> extends AppResult<T> {
  /// Creates a successful result.
  const AppSuccess(this.value);

  /// Successful value.
  final T value;
}

/// Failed operation result.
final class AppFailureResult<T> extends AppResult<T> {
  /// Creates a failed result.
  const AppFailureResult(this.error);

  /// Failure details.
  final AppFailure error;
}
