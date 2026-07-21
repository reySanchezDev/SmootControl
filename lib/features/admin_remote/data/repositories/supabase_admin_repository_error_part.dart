part of 'supabase_admin_repository.dart';

String _adminFriendlyMessage(String fallback, Object error) {
  final text = error.toString();
  final jsonStart = text.indexOf('{');
  if (jsonStart >= 0) {
    try {
      final decoded = jsonDecode(text.substring(jsonStart));
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } on Object {
      // Keep fallback when the remote error is not JSON.
    }
  }
  if (text.contains('Sesion remota expirada')) {
    return 'La sesion remota expiro. Vuelve a iniciar sesion.';
  }
  return fallback;
}
