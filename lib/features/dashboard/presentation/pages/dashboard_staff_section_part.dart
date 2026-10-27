part of 'dashboard_page.dart';

_DashboardSection _staffDashboardSection() {
  return const _DashboardSection(
    title: 'Personal',
    modules: [
      _ModuleDefinition(
        icon: Icons.badge_outlined,
        label: 'Personal',
        route: AppRoutes.staff,
      ),
      _ModuleDefinition(
        icon: Icons.work_outline,
        label: 'Puestos',
        route: AppRoutes.staffPositions,
      ),
      _ModuleDefinition(
        icon: Icons.receipt_long_outlined,
        label: 'Consumos personal',
        route: AppRoutes.staffConsumptions,
      ),
      _ModuleDefinition(
        icon: Icons.restaurant_menu_outlined,
        label: 'Consumo materia',
        route: AppRoutes.rawMaterialStaffConsumptions,
      ),
      _ModuleDefinition(
        icon: Icons.payments_outlined,
        label: 'Adelantos',
        route: AppRoutes.salaryAdvances,
      ),
      _ModuleDefinition(
        icon: Icons.summarize_outlined,
        label: 'Planilla',
        route: AppRoutes.payroll,
      ),
      _ModuleDefinition(
        icon: Icons.more_time_outlined,
        label: 'Horas extras',
        route: AppRoutes.staffOvertime,
      ),
      _ModuleDefinition(
        icon: Icons.schedule_outlined,
        label: 'Marcadas',
        route: AppRoutes.attendance,
      ),
      _ModuleDefinition(
        icon: Icons.beach_access_outlined,
        label: 'Vacaciones',
        route: AppRoutes.vacations,
      ),
      _ModuleDefinition(
        icon: Icons.fact_check_outlined,
        label: 'Autorizar extras',
        route: AppRoutes.overtimeApprovals,
      ),
      _ModuleDefinition(
        icon: Icons.history_outlined,
        label: 'Pagos planilla',
        route: AppRoutes.staffPayrollPayments,
      ),
    ],
  );
}
