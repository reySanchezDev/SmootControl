/// Runtime configuration used to connect SmooControl with Supabase.
final class SupabaseAppConfig {
  /// Creates a Supabase app configuration.
  const SupabaseAppConfig({
    String supabaseUrl = const String.fromEnvironment('SMOO_SUPABASE_URL'),
    String publishableKey = const String.fromEnvironment(
      'SMOO_SUPABASE_PUBLISHABLE_KEY',
    ),
  }) : _supabaseUrl = supabaseUrl,
       _publishableKey = publishableKey;

  final String _supabaseUrl;
  final String _publishableKey;

  /// Supabase project URL without trailing slash.
  String get supabaseUrl => _supabaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  /// Supabase public publishable key.
  String get publishableKey => _publishableKey.trim();

  /// Whether all connection and auth values are present.
  bool get isConfigured {
    return supabaseUrl.isNotEmpty && publishableKey.isNotEmpty;
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

  /// Supabase email/password signup endpoint.
  Uri get signupUri => Uri.parse('$supabaseUrl/auth/v1/signup');

  /// Supabase RPC endpoint.
  Uri rpcUri(String functionName) {
    return Uri.parse('$supabaseUrl/rest/v1/rpc/$functionName');
  }
}
