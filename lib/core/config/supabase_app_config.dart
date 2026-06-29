/// Runtime configuration used to connect SmooControl with Supabase.
final class SupabaseAppConfig {
  /// Creates a Supabase app configuration.
  const SupabaseAppConfig({
    String supabaseUrl = const String.fromEnvironment('SMOO_SUPABASE_URL'),
    String publishableKey = const String.fromEnvironment(
      'SMOO_SUPABASE_PUBLISHABLE_KEY',
    ),
    String authEmail = const String.fromEnvironment(
      'SMOO_SUPABASE_AUTH_EMAIL',
    ),
    String authPassword = const String.fromEnvironment(
      'SMOO_SUPABASE_AUTH_PASSWORD',
    ),
  }) : _supabaseUrl = supabaseUrl,
       _publishableKey = publishableKey,
       _authEmail = authEmail,
       _authPassword = authPassword;

  final String _supabaseUrl;
  final String _publishableKey;
  final String _authEmail;
  final String _authPassword;

  /// Supabase project URL without trailing slash.
  String get supabaseUrl => _supabaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  /// Supabase public publishable key.
  String get publishableKey => _publishableKey.trim();

  /// Technical auth email used by the tablet to pass Supabase RLS.
  String get authEmail => _authEmail.trim();

  /// Technical auth password used by the tablet to pass Supabase RLS.
  String get authPassword => _authPassword;

  /// Whether all connection and auth values are present.
  bool get isConfigured {
    return supabaseUrl.isNotEmpty &&
        publishableKey.isNotEmpty &&
        authEmail.isNotEmpty &&
        authPassword.isNotEmpty;
  }

  /// REST endpoint for a public table.
  Uri restUri(String table, [Map<String, String>? queryParameters]) {
    return Uri.parse(
      '$supabaseUrl/rest/v1/$table',
    ).replace(queryParameters: queryParameters);
  }

  /// Supabase password grant endpoint.
  Uri get passwordGrantUri {
    return Uri.parse('$supabaseUrl/auth/v1/token').replace(
      queryParameters: const {'grant_type': 'password'},
    );
  }
}
