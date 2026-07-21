/// Converts low-level sync exceptions into actionable operator messages.
String syncErrorMessage(Object error) {
  return syncErrorText(error.toString());
}

/// Converts a stored sync error string into an actionable operator message.
String syncErrorText(String raw) {
  final text = raw.trim();
  if (_looksLikeHostLookupFailure(text)) {
    return 'No se pudo conectar con Supabase porque el dispositivo no resolvio '
        'el servidor. Revisa Wi-Fi/datos, DNS o modo avion y toca Reintentar. '
        'La venta sigue guardada localmente.';
  }
  if (_looksLikeTimeout(text)) {
    return 'La conexion con Supabase tardo demasiado. Revisa la red y toca '
        'Reintentar. La venta sigue guardada localmente.';
  }
  return text;
}

bool _looksLikeHostLookupFailure(String text) {
  final lower = text.toLowerCase();
  return lower.contains('failed host lookup') ||
      lower.contains('no address associated with hostname') ||
      lower.contains('socketexception');
}

bool _looksLikeTimeout(String text) {
  final lower = text.toLowerCase();
  return lower.contains('timeoutexception') || lower.contains('timed out');
}
