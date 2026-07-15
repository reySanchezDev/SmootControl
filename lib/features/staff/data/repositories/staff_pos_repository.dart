import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/staff/data/datasources/local_staff_datasource.dart';
import 'package:smoo_control/features/staff/domain/entities/business_rule.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';
import 'package:smoo_control/features/staff/domain/entities/employee_overtime_entry.dart';
import 'package:smoo_control/features/staff/domain/entities/employee_position.dart';
import 'package:smoo_control/features/staff/domain/entities/payroll_pending_line.dart';
import 'package:smoo_control/features/staff/domain/entities/salary_advance.dart';
import 'package:smoo_control/features/staff/domain/repositories/i_staff_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';

/// POS repository backed by local data and sync queue.
final class StaffPosRepository implements IStaffRepository {
  /// Creates the repository.
  const StaffPosRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
  }) : _syncQueueRepository = syncQueueRepository;

  final LocalStaffDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;

  @override
  Future<AppResult<List<Employee>>> getEmployees() async {
    try {
      return AppSuccess(await _localDataSource.getActiveEmployees());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'employees_read_failed',
          message: 'No se pudo leer el personal local.',
          cause: error,
        ),
      );
    }
  }

  /// Returns a local business rule value for POS flows.
  Future<bool> getBoolRule(String key, {required bool defaultValue}) {
    return _localDataSource.getBoolRule(key, defaultValue: defaultValue);
  }

  @override
  Future<AppResult<SalaryAdvance>> saveSalaryAdvance(
    SalaryAdvance advance,
  ) async {
    try {
      final saved = await _localDataSource.saveSalaryAdvance(advance);
      await _syncQueueRepository?.enqueue(
        entityType: 'salary_advances',
        entityId: saved.id,
        operation: SyncOperation.create,
        payload: {
          'id': saved.id,
          'employeeId': saved.employeeId,
          'cashRegisterSessionId': saved.cashRegisterSessionId,
          'amountInCents': saved.amountInCents,
          'affectsCash': saved.affectsCash,
          'note': saved.note,
          'createdBy': saved.createdBy,
          'status': saved.status,
          'createdAt': saved.createdAt.toIso8601String(),
          'deliveredAt': saved.deliveredAt.toIso8601String(),
        },
      );
      return AppSuccess(saved);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'salary_advance_save_failed',
          message: 'No se pudo guardar el adelanto de salario.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<BusinessRule>>> getBusinessRules() async {
    return const AppSuccess(<BusinessRule>[]);
  }

  @override
  Future<AppResult<List<SalaryAdvance>>> getSalaryAdvances() async {
    return const AppSuccess(<SalaryAdvance>[]);
  }

  @override
  Future<AppResult<List<EmployeeOvertimeEntry>>> getOvertimeEntries() async {
    return const AppSuccess(<EmployeeOvertimeEntry>[]);
  }

  @override
  Future<AppResult<List<EmployeePosition>>> getPositions() async {
    return const AppSuccess(<EmployeePosition>[]);
  }

  @override
  Future<AppResult<List<PayrollPendingLine>>> getPendingPayrollLines() async {
    return const AppSuccess(<PayrollPendingLine>[]);
  }

  @override
  Future<AppResult<void>> postPayrollEmployee({
    required String employeeId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required int baseSalaryInCents,
    required int consumptionInCents,
    required int overtimeInCents,
    required int salaryAdvanceDeductionInCents,
    required int paymentAmountInCents,
  }) async {
    return const AppFailureResult(
      AppFailure(
        code: 'payroll_local_write_blocked',
        message: 'La planilla se administra desde el modo administrador.',
      ),
    );
  }

  @override
  Future<AppResult<void>> deleteOvertimeEntry(String overtimeId) async {
    return const AppFailureResult(
      AppFailure(
        code: 'overtime_local_write_blocked',
        message: 'Las horas extras se administran desde el modo administrador.',
      ),
    );
  }

  @override
  Future<AppResult<EmployeeOvertimeEntry>> saveOvertimeEntry(
    EmployeeOvertimeEntry entry,
  ) async {
    return const AppFailureResult(
      AppFailure(
        code: 'overtime_local_write_blocked',
        message: 'Las horas extras se administran desde el modo administrador.',
      ),
    );
  }

  @override
  Future<AppResult<BusinessRule>> saveBusinessRule(BusinessRule rule) async {
    return const AppFailureResult(
      AppFailure(
        code: 'business_rule_local_write_blocked',
        message: 'Las reglas se administran desde el modo administrador.',
      ),
    );
  }

  @override
  Future<AppResult<Employee>> saveEmployee(Employee employee) async {
    return const AppFailureResult(
      AppFailure(
        code: 'employee_local_write_blocked',
        message: 'El personal se administra desde el modo administrador.',
      ),
    );
  }

  @override
  Future<AppResult<EmployeePosition>> savePosition(
    EmployeePosition position,
  ) async {
    return const AppFailureResult(
      AppFailure(
        code: 'position_local_write_blocked',
        message: 'Los puestos se administran desde el modo administrador.',
      ),
    );
  }
}
