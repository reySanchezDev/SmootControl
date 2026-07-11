part of 'supabase_catalog_pull_service.dart';

extension on SupabaseCatalogPullService {
  Future<void> _applyBusinessSettings(
    List<Map<String, Object?>> restaurantRows,
    List<Map<String, Object?>> invoiceRows,
  ) async {
    if (restaurantRows.isEmpty && invoiceRows.isEmpty) return;

    final now = DateTime.now();
    final existing = await (_database.select(
      _database.localBusinessSettings,
    )..where((settings) => settings.id.equals('default'))).getSingleOrNull();
    final restaurant = restaurantRows.isEmpty ? null : restaurantRows.first;
    final invoice = invoiceRows.isEmpty ? null : invoiceRows.first;

    final remoteNextInvoiceNumber = _int(
      invoice?['next_number'],
      defaultValue: 1,
    );
    final localNextInvoiceFloor = await _localNextInvoiceFloor(
      existing: existing,
      prefix:
          _optionalText(invoice?['prefix']) ?? existing?.invoicePrefix ?? 'F',
    );

    await _database
        .into(_database.localBusinessSettings)
        .insert(
          LocalBusinessSettingsCompanion(
            id: const Value('default'),
            businessName: Value(
              _optionalText(restaurant?['commercial_name']) ??
                  existing?.businessName ??
                  'SmooControl',
            ),
            legalName: Value(
              _optionalText(restaurant?['legal_name']) ?? existing?.legalName,
            ),
            taxNumber: Value(
              _optionalText(restaurant?['tax_identifier']) ??
                  existing?.taxNumber,
            ),
            phone: Value(
              _optionalText(restaurant?['phone']) ?? existing?.phone,
            ),
            address: Value(
              _optionalText(restaurant?['address']) ?? existing?.address,
            ),
            showCompanyInfoOnReceipts: Value(
              restaurant == null
                  ? existing?.showCompanyInfoOnReceipts ?? true
                  : _bool(
                      restaurant['show_company_data_on_pdf'],
                      defaultValue: true,
                    ),
            ),
            invoicePrefix: Value(
              _optionalText(invoice?['prefix']) ??
                  existing?.invoicePrefix ??
                  'F',
            ),
            initialInvoiceNumber: Value(
              _int(invoice?['initial_number'], defaultValue: 1),
            ),
            nextInvoiceNumber: Value(
              remoteNextInvoiceNumber > localNextInvoiceFloor
                  ? remoteNextInvoiceNumber
                  : localNextInvoiceFloor,
            ),
            remoteId: Value(_restaurantService.restaurantId),
            syncStatus: const Value('synced'),
            syncError: const Value(null),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
            syncedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<int> _localNextInvoiceFloor({
    required LocalBusinessSetting? existing,
    required String prefix,
  }) async {
    final currentNext = existing?.nextInvoiceNumber ?? 1;
    final initialNumber = existing?.initialInvoiceNumber ?? 1;
    var floor = currentNext > initialNumber ? currentNext : initialNumber;
    final normalizedPrefix = prefix.trim().toUpperCase();
    final sales = await _database.select(_database.localSales).get();
    for (final sale in sales) {
      final nextNumber = _nextInvoiceNumberAfter(
        sale.invoiceNumber,
        prefix: normalizedPrefix,
      );
      if (nextNumber != null && nextNumber > floor) {
        floor = nextNumber;
      }
    }
    return floor;
  }

  int? _nextInvoiceNumberAfter(String invoiceNumber, {required String prefix}) {
    final trimmed = invoiceNumber.trim().toUpperCase();
    final prefixWithoutDash = prefix.endsWith('-')
        ? prefix.substring(0, prefix.length - 1)
        : prefix;
    if (prefixWithoutDash.isNotEmpty &&
        !trimmed.startsWith(prefixWithoutDash)) {
      return null;
    }
    final match = RegExp(r'(\d+)$').firstMatch(trimmed);
    if (match == null) return null;
    final value = int.tryParse(match.group(1)!);
    if (value == null) return null;
    return value + 1;
  }
}
