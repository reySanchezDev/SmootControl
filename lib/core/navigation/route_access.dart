import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/roles/domain/services/access_control_service.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Permission codes required by navigable application routes.
abstract final class RouteAccess {
  /// Returns any accepted permission for one route.
  static List<String> anyPermissionsFor(String? route) {
    return switch (route) {
      AppRoutes.pos => const ['ventas.registrar'],
      AppRoutes.reports ||
      AppRoutes.reportSummary ||
      AppRoutes.cashClosingReport ||
      AppRoutes.dailySalesReport ||
      AppRoutes.productPerformanceReport ||
      AppRoutes.expensesReport ||
      AppRoutes.monthlyOperationalReport ||
      AppRoutes.inventoryValueReport ||
      AppRoutes.negativeInventoryReport ||
      AppRoutes.payrollPaymentsReport => const ['reportes.ver'],
      AppRoutes.catalog ||
      AppRoutes.products ||
      AppRoutes.recipes ||
      AppRoutes.measurementUnits => const ['productos.gestionar'],
      AppRoutes.inventory ||
      AppRoutes.inventoryMovements => const ['inventario.gestionar'],
      AppRoutes.packaging => const [
        'empaques.gestionar',
        'tipos_venta.gestionar',
      ],
      AppRoutes.modifiers => const ['modificadores.gestionar'],
      AppRoutes.paymentMethods => const ['pagos.gestionar'],
      AppRoutes.tables => const ['mesas.gestionar'],
      AppRoutes.sales => const [
        'ventas.registrar',
        'ventas.anular',
        'pdf.generar',
      ],
      AppRoutes.cashRegisters => const ['caja.aperturar', 'caja.cerrar'],
      AppRoutes.expenses => const [
        'gastos.registrar',
        'gastos.categorias.gestionar',
      ],
      AppRoutes.settings => const ['configuracion.gestionar'],
      AppRoutes.exchangeRates => const ['tasas.gestionar'],
      AppRoutes.roles => const ['roles.gestionar'],
      AppRoutes.users => const ['usuarios.gestionar'],
      AppRoutes.audit => const ['auditoria.ver'],
      AppRoutes.staff => const ['personal.gestionar'],
      AppRoutes.staffPositions => const ['personal.gestionar'],
      AppRoutes.staffConsumptions => const ['personal.consumos.ver'],
      AppRoutes.salaryAdvances => const ['personal.adelantos.gestionar'],
      AppRoutes.payroll ||
      AppRoutes.staffOvertime ||
      AppRoutes.staffPayrollPayments => const ['planilla.gestionar'],
      AppRoutes.businessRules => const ['reglas_negocio.gestionar'],
      AppRoutes.sync => const ['sync.configurar'],
      AppRoutes.systemMaintenance => const ['sistema.reiniciar_operacion'],
      _ => const <String>[],
    };
  }
}

/// Guards one page with the permissions required for its route.
class RouteAccessGuard extends StatelessWidget {
  /// Creates a route access guard.
  const RouteAccessGuard({
    required this.anyPermissions,
    required this.child,
    super.key,
  });

  /// Any accepted permission code.
  final List<String> anyPermissions;

  /// Page rendered when access is granted.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (anyPermissions.isEmpty || _isAdmin) return child;

    final session = serviceLocator<CurrentOperatorService>().session;
    if (session == null) {
      return _AccessDenied(message: AppLocalizations.of(context).loginTitle);
    }

    return FutureBuilder<AppResult<bool>>(
      future: serviceLocator<AccessControlService>().hasAnyPermission(
        roleId: session.roleId,
        permissionCodes: anyPermissions,
      ),
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result == null) return const AppLoadingPage();

        return result.when(
          success: (allowed) {
            if (allowed) return child;
            return _AccessDenied(
              message: AppLocalizations.of(context).accessDeniedMessage,
            );
          },
          failure: (failure) => _AccessDenied(message: failure.message),
        );
      },
    );
  }

  bool get _isAdmin {
    final session = serviceLocator<CurrentOperatorService>().session;
    return session?.roleId == DefaultAccessRoles.adminId;
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPageScaffold(
      title: l10n.accessDeniedTitle,
      body: AppEmptyState(
        icon: Icons.lock_outline,
        message: message,
        title: l10n.accessDeniedTitle,
      ),
    );
  }
}
