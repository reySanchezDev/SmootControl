part of 'supabase_staff_admin_repository.dart';

mixin _SupabaseStaffPayrollMixin on _SupabaseStaffAdminRepositoryBase {
  Future<AppResult<List<PayrollPendingLine>>> getPendingPayrollLines() {
    return _guard(
      'pending_payroll_lines_read_failed',
      'No se pudieron leer saldos pendientes de planilla.',
      () async {
        final rows = await _rpcRows('app_get_pending_payroll_lines', {
          'p_restaurant_id': _restaurantId,
        });
        return rows.map(_pendingPayrollLineFromRow).toList();
      },
    );
  }

  Future<AppResult<void>> postPayrollEmployee({
    required String employeeId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required int baseSalaryInCents,
    required int consumptionInCents,
    required int overtimeInCents,
    required int salaryAdvanceDeductionInCents,
    required int paymentAmountInCents,
  }) {
    return _guard(
      'payroll_employee_post_failed',
      'No se pudo pagar la planilla del empleado.',
      () async {
        await _rpc('app_post_payroll_employee', {
          'p_restaurant_id': _restaurantId,
          'p_payload': {
            'employee_id': employeeId,
            'period_start': _dateOnly(periodStart),
            'period_end': _dateOnly(periodEnd),
            'base_salary': _money(baseSalaryInCents),
            'overtime_amount': _money(overtimeInCents),
            'staff_consumption_amount': _money(consumptionInCents),
            'salary_advance_deduction': _money(
              salaryAdvanceDeductionInCents,
            ),
            'payment_amount': _money(paymentAmountInCents),
          },
        });
      },
    );
  }
}
