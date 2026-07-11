part of 'supabase_staff_admin_repository.dart';

mixin _SupabaseStaffConsumptionsMixin on _SupabaseStaffAdminRepositoryBase {
  Future<AppResult<List<StaffConsumption>>> getStaffConsumptions() {
    return _guard(
      'staff_consumptions_read_failed',
      'No se pudieron leer consumos de personal.',
      () async {
        final rows = await _getRows('sales', {
          'restaurant_id': 'eq.$_restaurantId',
          'sale_kind': 'eq.staff_consumption',
          'select':
              'id,employee_id,invoice_number,internal_receipt_number,'
              'total_amount,payroll_run_id,sold_at,employees(full_name)',
          'order': 'sold_at.desc',
        });
        return rows.map((row) {
          final employee = row['employees'];
          final employeeName = employee is Map<String, Object?>
              ? _text(
                  employee['full_name'],
                  defaultValue: 'Empleado',
                )
              : 'Empleado';
          return StaffConsumption(
            id: _text(row['id']),
            employeeId: _text(row['employee_id']),
            employeeName: employeeName,
            receiptLabel:
                _optionalText(row['invoice_number']) ??
                'CP-${_text(row['internal_receipt_number'])}',
            totalInCents: _moneyToCents(row['total_amount']),
            payrollRunId: _optionalText(row['payroll_run_id']),
            createdAt:
                DateTime.tryParse(_text(row['sold_at'])) ?? DateTime.now(),
          );
        }).toList();
      },
    );
  }

  /// Returns one staff-consumption detail.
  Future<AppResult<List<StaffConsumptionItem>>> getStaffConsumptionItems(
    String saleId,
  ) {
    return _guard(
      'staff_consumption_items_read_failed',
      'No se pudo leer el detalle del consumo.',
      () async {
        final rows = await _getRows('sale_items', {
          'sale_id': 'eq.$saleId',
          'select':
              'product_name,selected_options_label,quantity,unit_price,'
              'subtotal',
          'order': 'created_at.asc',
        });
        return rows
            .map(
              (row) => StaffConsumptionItem(
                productName: _text(row['product_name']),
                selectedOptionsLabel: _optionalText(
                  row['selected_options_label'],
                ),
                quantity: _moneyToCents(row['quantity']) ~/ 100,
                unitPriceInCents: _moneyToCents(row['unit_price']),
                totalInCents: _moneyToCents(row['subtotal']),
              ),
            )
            .toList();
      },
    );
  }

  /// Permanently deletes one staff consumption and its detail from Supabase.
  Future<AppResult<void>> deleteStaffConsumption(String saleId) {
    return _guard(
      'staff_consumption_delete_failed',
      'No se pudo eliminar el consumo de personal.',
      () async {
        await _rpc('app_delete_staff_consumption', {
          'p_restaurant_id': _restaurantId,
          'p_sale_id': saleId,
        });
      },
    );
  }
}
