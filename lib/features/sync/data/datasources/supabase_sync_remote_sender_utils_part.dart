part of 'supabase_sync_remote_sender.dart';

extension on SupabaseSyncRemoteSender {
  Future<void> _applyRemoteSaleResult({
    required Map<String, Object?> result,
    required Map<String, Object?> salePayload,
    bool updateInvoiceSettings = true,
  }) async {
    final localSaleId = _optionalText(salePayload['id']);
    final remoteInvoiceNumber = _optionalText(result['invoice_number']);
    if (localSaleId == null || remoteInvoiceNumber == null) return;

    final now = DateTime.now();
    final currentInvoiceNumber = _optionalText(salePayload['invoiceNumber']);
    await (_database.update(
      _database.localSales,
    )..where((sale) => sale.id.equals(localSaleId))).write(
      LocalSalesCompanion(
        invoiceNumber: Value(
          currentInvoiceNumber == remoteInvoiceNumber
              ? currentInvoiceNumber!
              : remoteInvoiceNumber,
        ),
        internalReceiptNumber: Value(
          _optionalInt(result['internal_receipt_number']),
        ),
        syncStatus: const Value('synced'),
        syncError: const Value(null),
        updatedAt: Value(now),
        syncedAt: Value(now),
      ),
    );

    if (!updateInvoiceSettings) return;

    final nextInvoiceNumber = _nextInvoiceNumberAfter(remoteInvoiceNumber);
    if (nextInvoiceNumber == null) return;
    final settings = await (_database.select(
      _database.localBusinessSettings,
    )..where((row) => row.id.equals('default'))).getSingleOrNull();
    if (settings == null || settings.nextInvoiceNumber >= nextInvoiceNumber) {
      return;
    }

    await (_database.update(
      _database.localBusinessSettings,
    )..where((row) => row.id.equals('default'))).write(
      LocalBusinessSettingsCompanion(
        nextInvoiceNumber: Value(nextInvoiceNumber),
        updatedAt: Value(now),
        syncedAt: Value(now),
      ),
    );
  }

  int? _nextInvoiceNumberAfter(String invoiceNumber) {
    final match = RegExp(r'(\d+)$').firstMatch(invoiceNumber.trim());
    if (match == null) return null;
    final value = int.tryParse(match.group(1)!);
    if (value == null) return null;
    return value + 1;
  }

  int? _optionalInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  Future<String> _deviceUserId() async {
    final state = await (_database.select(
      _database.localDeviceState,
    )..where((row) => row.id.equals('default'))).getSingleOrNull();
    final userId = _optionalText(state?.initializedByUserId);
    if (userId == null) {
      throw StateError('No se pudo resolver el usuario local del dispositivo.');
    }
    return userId;
  }

  num _money(int cents) => cents / 100;

  num? _optionalMoney(Object? value) {
    if (value == null) return null;
    return _money(_intValue(value));
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String? _dateOnly(Object? value) {
    final text = value?.toString();
    if (text == null || text.length < 10) return text;
    return text.substring(0, 10);
  }

  String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Map<String, Object?> _mapPayload(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  List<Map<String, Object?>> _listPayload(Object? value) {
    if (value is! List) return const [];
    return value.map(_mapPayload).toList();
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  String _roleCode(Object? value) {
    final id = value?.toString().trim();
    if (id == null || id.isEmpty) return _uuid.v4();
    return switch (id) {
      'role-admin' => 'admin',
      'role-cashier' => 'cashier',
      'role-waiter' => 'waiter',
      _ => id,
    };
  }

  String? _uuidOrNull(Object? value) {
    final text = value?.toString();
    if (text == null) return null;
    final normalized = text.trim();
    if (RegExp(
      '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-'
      '[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      '[0-9a-fA-F]{12}'
      r'$',
    ).hasMatch(normalized)) {
      return normalized;
    }
    return null;
  }

  String _remoteUuid(Object? value, {required String scope}) {
    final directUuid = _uuidOrNull(value);
    if (directUuid != null) return directUuid;

    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      throw StateError('No se pudo generar UUID remoto para $scope.');
    }

    return _uuid.v5(
      Namespace.url.value,
      'smoo-control:$_restaurantId:$scope:$text',
    );
  }

  String? _nullableRemoteUuid(Object? value, {required String scope}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;

    return _remoteUuid(text, scope: scope);
  }
}
