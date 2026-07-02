/// Keeps the current remote administrator session in memory.
///
/// Administrative screens use this token to read/write Supabase directly after
/// the owner signs in or creates the first remote admin. Nothing here is
/// persisted; the POS keeps its offline login by local PIN.
final class CurrentRemoteSessionService {
  String? _accessToken;
  String? _userId;
  DateTime? _expiresAt;

  /// Current remote user id, when a remote admin session is active.
  String? get userId => _userId;

  /// Returns a usable access token, or null when there is no valid session.
  String? get accessToken {
    final token = _accessToken;
    if (token == null || token.isEmpty) return null;

    final expiration = _expiresAt;
    if (expiration != null &&
        !expiration.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      clear();
      return null;
    }

    return token;
  }

  /// Whether a current remote admin token can be used safely.
  bool get hasUsableToken => accessToken != null;

  /// Stores the remote admin session for the current app runtime.
  void set({
    required String accessToken,
    required String userId,
    DateTime? expiresAt,
  }) {
    _accessToken = accessToken;
    _userId = userId;
    _expiresAt = expiresAt;
  }

  /// Clears the in-memory remote session.
  void clear() {
    _accessToken = null;
    _userId = null;
    _expiresAt = null;
  }
}
