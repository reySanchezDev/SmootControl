import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/staff/domain/entities/business_rule.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';
import 'package:smoo_control/features/staff/domain/entities/employee_overtime_entry.dart';
import 'package:smoo_control/features/staff/domain/entities/employee_position.dart';
import 'package:smoo_control/features/staff/domain/entities/payroll_pending_line.dart';
import 'package:smoo_control/features/staff/domain/entities/salary_advance.dart';
import 'package:smoo_control/features/staff/domain/entities/staff_consumption.dart';
import 'package:smoo_control/features/staff/domain/repositories/i_staff_repository.dart';

part 'supabase_staff_admin_repository_advances_part.dart';
part 'supabase_staff_admin_repository_base_part.dart';
part 'supabase_staff_admin_repository_business_part.dart';
part 'supabase_staff_admin_repository_consumptions_part.dart';
part 'supabase_staff_admin_repository_employees_part.dart';
part 'supabase_staff_admin_repository_overtime_part.dart';
part 'supabase_staff_admin_repository_payroll_part.dart';

/// Remote-only staff repository used by administrative screens.
final class SupabaseStaffAdminRepository
    extends _SupabaseStaffAdminRepositoryBase
    with
        _SupabaseStaffEmployeesMixin,
        _SupabaseStaffBusinessMixin,
        _SupabaseStaffAdvancesMixin,
        _SupabaseStaffConsumptionsMixin,
        _SupabaseStaffOvertimeMixin,
        _SupabaseStaffPayrollMixin
    implements IStaffRepository {
  /// Creates the repository.
  const SupabaseStaffAdminRepository({
    required super.config,
    required super.restaurantService,
    required super.remoteSessionService,
    required super.client,
  });
}
