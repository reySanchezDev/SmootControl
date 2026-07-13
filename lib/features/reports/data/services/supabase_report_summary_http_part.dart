part of 'supabase_report_summary_service.dart';

extension _SupabaseReportSummaryHttp on SupabaseReportSummaryService {
  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> queryParameters,
  ) async {
    final response = await _client.get(
      _config.restUri(table, queryParameters),
      headers: await _headers(),
    );
    _ensureSuccess(response, table);

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  Future<Map<String, String>> _headers() async {
    return {
      'apikey': _config.publishableKey,
      'Authorization': 'Bearer ${await _token()}',
      'Content-Type': 'application/json',
    };
  }

  Future<String> _token() async {
    final sessionToken = _remoteSessionService.accessToken;
    if (sessionToken != null) return sessionToken;

    throw StateError(
      'La sesion remota expiro. Inicia sesion como administrador remoto.',
    );
  }

  void _ensureSuccess(http.Response response, String table) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      _remoteSessionService.expire();
    }

    throw StateError(
      'Supabase rechazo consulta de reportes en $table '
      '(${response.statusCode}): ${response.body}',
    );
  }

  String _dateRangeFilter(String column, DateTime from, DateTime to) {
    return '($column.gte.${from.toUtc().toIso8601String()},'
        '$column.lt.${to.toUtc().toIso8601String()})';
  }

  String _inFilter(Set<String> values) {
    return 'in.(${values.join(',')})';
  }

  String _requiredText(Map<String, Object?> row, String key) {
    final value = _optionalText(row[key]);
    if (value == null) throw StateError('Missing required field $key.');
    return value;
  }

  String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  DateTime _dateTime(Object? value) {
    final text = _optionalText(value);
    if (text == null) throw StateError('Missing remote date.');
    return DateTime.parse(text).toLocal();
  }

  int _moneyToCents(Object? value) {
    if (value == null) return 0;
    if (value is num) return (value * 100).round();
    return ((num.tryParse(value.toString()) ?? 0) * 100).round();
  }

  int _quantity(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.round();
    return (num.tryParse(value.toString()) ?? 0).round();
  }
}
