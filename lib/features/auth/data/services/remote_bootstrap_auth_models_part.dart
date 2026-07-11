part of 'remote_bootstrap_auth_service.dart';

enum _SignUpResult { created, existing }

final class _SupabaseHttpException implements Exception {
  const _SupabaseHttpException({
    required this.table,
    required this.statusCode,
    required this.body,
  });

  final String table;
  final int statusCode;
  final String body;

  @override
  String toString() {
    return 'Supabase rechazo $table ($statusCode): $body';
  }
}
