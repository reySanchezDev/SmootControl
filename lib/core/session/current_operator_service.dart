import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';

/// Provides the current authenticated operator.
final class CurrentOperatorService {
  /// Creates a current operator service.
  const CurrentOperatorService();

  /// Current authenticated session stored in memory.
  static AuthSession? currentSession;

  /// Local fallback user used by tests and legacy records.
  static const localUserId = 'usuario-local';

  /// Current operator identifier for audit and operational records.
  String get userId => currentSession?.userId ?? localUserId;

  /// Current authenticated session, if any.
  AuthSession? get session => currentSession;

  /// Whether an operator is authenticated.
  bool get isAuthenticated => currentSession != null;

  /// Clears the current authenticated operator.
  void clear() {
    currentSession = null;
  }
}
