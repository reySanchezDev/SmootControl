part of 'supabase_admin_repository.dart';

mixin _SupabaseAdminSettingsMixin on _SupabaseAdminRepositoryBase
    implements IBusinessSettingsRepository {
  @override
  Future<AppResult<BusinessSettings>> getSettings() async {
    return _guard(
      'business_settings_read_failed',
      'No se pudo leer configuracion.',
      () async {
        final restaurants = await _getRows('restaurants', {
          'id': 'eq.$_restaurantId',
          'select': '*',
          'limit': '1',
        });
        final invoices = await _getRows('invoice_number_settings', {
          'restaurant_id': 'eq.$_restaurantId',
          'select': '*',
          'limit': '1',
        });
        final restaurant = restaurants.isEmpty
            ? const <String, Object?>{}
            : restaurants.first;
        final invoice = invoices.isEmpty
            ? const <String, Object?>{}
            : invoices.first;
        return BusinessSettings(
          businessName: _text(
            restaurant['commercial_name'],
            fallback: BusinessSettings.empty.businessName,
          ),
          legalName: _nullableText(restaurant['legal_name']),
          taxNumber: _nullableText(restaurant['tax_identifier']),
          phone: _nullableText(restaurant['phone']),
          address: _nullableText(restaurant['address']),
          showCompanyInfoOnReceipts: _bool(
            restaurant['show_company_data_on_pdf'],
            fallback: true,
          ),
          invoicePrefix: _text(invoice['prefix'], fallback: 'F'),
          initialInvoiceNumber: _int(
            invoice['initial_number'],
            fallback: 1,
          ),
          nextInvoiceNumber: _int(invoice['next_number'], fallback: 1),
        );
      },
    );
  }

  @override
  Future<AppResult<BusinessSettings>> saveSettings(
    BusinessSettings settings, {
    bool syncRemote = true,
  }) async {
    return _guard(
      'business_settings_save_failed',
      'No se pudo guardar configuracion.',
      () async {
        await _upsert('restaurants', {
          'id': _restaurantId,
          'commercial_name': settings.businessName,
          'legal_name': settings.legalName,
          'tax_identifier': settings.taxNumber,
          'phone': settings.phone,
          'address': settings.address,
          'show_company_data_on_pdf': settings.showCompanyInfoOnReceipts,
          'updated_at': DateTime.now().toIso8601String(),
        });
        await _upsert(
          'invoice_number_settings',
          {
            'restaurant_id': _restaurantId,
            'prefix': settings.invoicePrefix,
            'initial_number': settings.initialInvoiceNumber,
            'next_number': settings.nextInvoiceNumber,
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictColumn: 'restaurant_id',
        );
        return settings;
      },
    );
  }
}
