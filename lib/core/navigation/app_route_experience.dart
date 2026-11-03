import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';

/// Functional experience of a route, independent of screen dimensions.
enum SmooExperience {
  /// Touch-first point of sale (phone or tablet).
  pos,

  /// Administrative web workspace, including compact browser layouts.
  backoffice,

  /// Dedicated attendance terminal; selected by build-time configuration.
  timeClock,
}

/// Explicit route ownership. Authorization and backend permissions are
/// checked separately; a visual route guard is not a security boundary for APIs.
abstract final class AppRouteExperience {
  static const _posRoutes = <String>{AppRoutes.pos};

  static const _backofficeRoutes = <String>{
    AppRoutes.dashboard,
    AppRoutes.reports,
    AppRoutes.reportSummary,
    AppRoutes.cashClosingReport,
    AppRoutes.dailySalesReport,
    AppRoutes.productPerformanceReport,
    AppRoutes.expensesReport,
    AppRoutes.monthlyOperationalReport,
    AppRoutes.inventoryValueReport,
    AppRoutes.negativeInventoryReport,
    AppRoutes.payrollPaymentsReport,
    AppRoutes.salaryAdvancesReport,
    AppRoutes.attendanceReport,
    AppRoutes.vacationSummaryReport,
    AppRoutes.catalog,
    AppRoutes.products,
    AppRoutes.recipes,
    AppRoutes.measurementUnits,
    AppRoutes.inventory,
    AppRoutes.inventoryMovements,
    AppRoutes.packaging,
    AppRoutes.modifiers,
    AppRoutes.paymentMethods,
    AppRoutes.tables,
    AppRoutes.sales,
    AppRoutes.cashRegisters,
    AppRoutes.expenses,
    AppRoutes.settings,
    AppRoutes.exchangeRates,
    AppRoutes.roles,
    AppRoutes.users,
    AppRoutes.audit,
    AppRoutes.staff,
    AppRoutes.staffPositions,
    AppRoutes.staffConsumptions,
    AppRoutes.rawMaterialStaffConsumptions,
    AppRoutes.salaryAdvances,
    AppRoutes.payroll,
    AppRoutes.staffOvertime,
    AppRoutes.attendance,
    AppRoutes.vacations,
    AppRoutes.overtimeApprovals,
    AppRoutes.staffPayrollPayments,
    AppRoutes.businessRules,
    AppRoutes.sync,
    AppRoutes.systemMaintenance,
  };

  /// Returns null for unknown routes (fail closed).
  static SmooExperience? forRoute(String? route) {
    if (route == null) return SmooExperience.backoffice;
    if (_posRoutes.contains(route)) return SmooExperience.pos;
    if (_backofficeRoutes.contains(route)) return SmooExperience.backoffice;
    return null;
  }

  /// A session can open only routes owned by its functional experience.
  static bool allows(AuthSession session, String? route) {
    final target = forRoute(route);
    if (target == null) return false;
    return session.isPosUser
        ? target == SmooExperience.pos
        : target == SmooExperience.backoffice;
  }
}
