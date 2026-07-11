part of 'supabase_staff_admin_repository.dart';

mixin _SupabaseStaffAdvancesMixin on _SupabaseStaffAdminRepositoryBase {
  Future<AppResult<List<SalaryAdvance>>> getSalaryAdvances() {
    return _guard(
      'salary_advances_read_failed',
      'No se pudieron leer adelantos.',
      () async {
        final rows = await _getRows('employee_salary_advances', {
          'restaurant_id': 'eq.$_restaurantId',
          'select':
              'id,employee_id,cash_register_session_id,amount,affects_cash,'
              'balance_amount,note,created_by_user_id,status,created_at,'
              'delivered_at',
          'order': 'delivered_at.desc,created_at.desc',
        });
        return rows.map(_advanceFromRow).toList();
      },
    );
  }

  Future<AppResult<SalaryAdvance>> saveSalaryAdvance(SalaryAdvance advance) {
    return _guard(
      'salary_advance_save_failed',
      'No se pudo guardar el adelanto.',
      () async {
        await _rpc('app_register_salary_advance', {
          'p_restaurant_id': _restaurantId,
          'p_payload': {
            'id': advance.id,
            'employee_id': advance.employeeId,
            'amount': _money(advance.amountInCents),
            'affects_cash': advance.affectsCash,
            'cash_register_session_id': advance.cashRegisterSessionId,
            'note': advance.note,
            'created_by_user_id': advance.createdBy,
            'created_at': advance.createdAt.toIso8601String(),
            'delivered_at': advance.deliveredAt.toIso8601String(),
          },
        });
        return advance;
      },
    );
  }

  /// Permanently deletes one salary advance from Supabase.
  Future<AppResult<void>> deleteSalaryAdvance(String advanceId) {
    return _guard(
      'salary_advance_delete_failed',
      'No se pudo eliminar el adelanto.',
      () async {
        await _rpc('app_delete_salary_advance', {
          'p_restaurant_id': _restaurantId,
          'p_advance_id': advanceId,
        });
      },
    );
  }
}
