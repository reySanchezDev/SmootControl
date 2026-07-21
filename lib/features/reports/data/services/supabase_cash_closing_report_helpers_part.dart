part of 'supabase_cash_closing_report_service.dart';

extension _SupabaseCashClosingReportHelpers
    on SupabaseCashClosingReportService {
  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> query,
  ) async {
    final response = await _client.get(
      _config.restUri(table, query),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        _remoteSessionService.expire();
      }
      throw StateError(
        'Supabase rechazo consulta de $table '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  Map<String, String> _headers() {
    return {
      'apikey': _config.publishableKey,
      'Authorization': 'Bearer ${_remoteSessionService.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  String _inFilter(Set<String> values) => 'in.(${values.join(',')})';

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _dateTime(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return DateTime.now();
    return DateTime.parse(text).toLocal();
  }

  int _moneyToCents(Object? value) {
    if (value == null) return 0;
    if (value is num) return (value * 100).round();
    return ((num.tryParse(value.toString()) ?? 0) * 100).round();
  }

  String _text(Map<String, Object?> row, String key) {
    final text = row[key]?.toString().trim();
    if (text == null || text.isEmpty) {
      throw StateError('Missing required field $key.');
    }
    return text;
  }

  String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

final class _RemoteCashSession {
  const _RemoteCashSession({
    required this.businessDate,
    required this.cashierId,
    required this.deviceId,
    required this.hasPhysicalCount,
    required this.id,
    required this.openingCashInCents,
    required this.physicalCashInCents,
    required this.status,
  });

  final DateTime businessDate;
  final String cashierId;
  final String? deviceId;
  final bool hasPhysicalCount;
  final String id;
  final int openingCashInCents;
  final int physicalCashInCents;
  final String status;
}

final class _RemoteSale {
  const _RemoteSale({
    required this.id,
    required this.methodId,
    required this.sessionId,
    required this.totalInCents,
  });

  final String id;
  final String methodId;
  final String sessionId;
  final int totalInCents;
}

final class _RemoteExpense {
  const _RemoteExpense({
    required this.amountInCents,
    required this.categoryId,
    required this.description,
    required this.sessionId,
    required this.spentAt,
  });

  final int amountInCents;
  final String categoryId;
  final String description;
  final String sessionId;
  final DateTime spentAt;
}

final class _RemotePaymentMethod {
  const _RemotePaymentMethod({
    this.affectsCash = false,
    this.groupName = 'Otros',
    this.name = 'Metodo',
  });

  final bool affectsCash;
  final String groupName;
  final String name;

  bool get isTransfer {
    final source = '$name $groupName'.toLowerCase();
    return source.contains('transfer');
  }
}
