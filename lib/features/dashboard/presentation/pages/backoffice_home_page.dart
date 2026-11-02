import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/navigation/backoffice_workspace.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/navigation/app_router.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/core/navigation/route_access.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/theme/backoffice_theme.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';

/// Entry point of the real Backoffice workspace for authenticated
/// non-POS users.
class BackofficeHomePage extends StatefulWidget {
  /// Creates the administrative entry point.
  const BackofficeHomePage({required this.session, super.key});

  /// Authenticated remote session.
  final AuthSession session;

  @override
  State<BackofficeHomePage> createState() => _BackofficeHomePageState();
}

class _BackofficeHomePageState extends State<BackofficeHomePage> {
  late Future<AppResult<Set<String>>> _permissions;

  static const _destinations = <BackofficeWorkspaceItem>[
    BackofficeWorkspaceItem(
      id: 'products',
      label: 'Productos',
      route: AppRoutes.products,
      icon: Icons.inventory_2_outlined,
      group: 'Catálogos',
    ),
    BackofficeWorkspaceItem(
      id: 'catalog',
      label: 'Categorías',
      route: AppRoutes.catalog,
      icon: Icons.category_outlined,
      group: 'Catálogos',
    ),
    BackofficeWorkspaceItem(
      id: 'recipes',
      label: 'Recetas',
      route: AppRoutes.recipes,
      icon: Icons.restaurant_menu_outlined,
      group: 'Catálogos',
    ),
    BackofficeWorkspaceItem(
      id: 'units',
      label: 'Unidades',
      route: AppRoutes.measurementUnits,
      icon: Icons.straighten_outlined,
      group: 'Catálogos',
    ),
    BackofficeWorkspaceItem(
      id: 'modifiers',
      label: 'Modificadores',
      route: AppRoutes.modifiers,
      icon: Icons.tune_outlined,
      group: 'Catálogos',
    ),
    BackofficeWorkspaceItem(
      id: 'payments',
      label: 'Métodos de pago',
      route: AppRoutes.paymentMethods,
      icon: Icons.payments_outlined,
      group: 'Catálogos',
    ),
    BackofficeWorkspaceItem(
      id: 'tables',
      label: 'Mesas',
      route: AppRoutes.tables,
      icon: Icons.table_restaurant_outlined,
      group: 'Catálogos',
    ),
    BackofficeWorkspaceItem(
      id: 'packaging',
      label: 'Empaques',
      route: AppRoutes.packaging,
      icon: Icons.takeout_dining_outlined,
      group: 'Catálogos',
    ),
    BackofficeWorkspaceItem(
      id: 'home',
      label: 'Inicio',
      route: AppRoutes.dashboard,
      icon: Icons.dashboard_outlined,
      group: 'Resumen',
    ),
    BackofficeWorkspaceItem(
      id: 'inventory',
      label: 'Inventario',
      route: AppRoutes.inventory,
      icon: Icons.warehouse_outlined,
      group: 'Operaciones',
    ),
    BackofficeWorkspaceItem(
      id: 'movements',
      label: 'Movimientos',
      route: AppRoutes.inventoryMovements,
      icon: Icons.swap_horiz,
      group: 'Operaciones',
    ),
    BackofficeWorkspaceItem(
      id: 'sales',
      label: 'Ventas',
      route: AppRoutes.sales,
      icon: Icons.receipt_long_outlined,
      group: 'Operaciones',
    ),
    BackofficeWorkspaceItem(
      id: 'cash',
      label: 'Caja',
      route: AppRoutes.cashRegisters,
      icon: Icons.point_of_sale_outlined,
      group: 'Operaciones',
    ),
    BackofficeWorkspaceItem(
      id: 'expenses',
      label: 'Gastos',
      route: AppRoutes.expenses,
      icon: Icons.request_quote_outlined,
      group: 'Operaciones',
    ),
    BackofficeWorkspaceItem(
      id: 'staff',
      label: 'Personal',
      route: AppRoutes.staff,
      icon: Icons.groups_outlined,
      group: 'Personal',
    ),
    BackofficeWorkspaceItem(
      id: 'attendance',
      label: 'Marcadas',
      route: AppRoutes.attendance,
      icon: Icons.schedule_outlined,
      group: 'Personal',
    ),
    BackofficeWorkspaceItem(
      id: 'vacations',
      label: 'Vacaciones',
      route: AppRoutes.vacations,
      icon: Icons.beach_access_outlined,
      group: 'Personal',
    ),
    BackofficeWorkspaceItem(
      id: 'payroll',
      label: 'Planilla',
      route: AppRoutes.payroll,
      icon: Icons.payments_outlined,
      group: 'Personal',
    ),
    BackofficeWorkspaceItem(
      id: 'reports',
      label: 'Reportes',
      route: AppRoutes.reports,
      icon: Icons.bar_chart_outlined,
      group: 'Reportes',
    ),
    BackofficeWorkspaceItem(
      id: 'settings',
      label: 'Configuración',
      route: AppRoutes.settings,
      icon: Icons.settings_outlined,
      group: 'Administración',
    ),
    BackofficeWorkspaceItem(
      id: 'exchange',
      label: 'Tasas de cambio',
      route: AppRoutes.exchangeRates,
      icon: Icons.currency_exchange_outlined,
      group: 'Administración',
    ),
    BackofficeWorkspaceItem(
      id: 'roles',
      label: 'Roles y permisos',
      route: AppRoutes.roles,
      icon: Icons.admin_panel_settings_outlined,
      group: 'Administración',
    ),
    BackofficeWorkspaceItem(
      id: 'audit',
      label: 'Auditoría',
      route: AppRoutes.audit,
      icon: Icons.manage_search_outlined,
      group: 'Administración',
    ),
    BackofficeWorkspaceItem(
      id: 'users',
      label: 'Usuarios',
      route: AppRoutes.users,
      icon: Icons.people_outline,
      group: 'Administración',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _permissions = _loadPermissions();
  }

  Future<AppResult<Set<String>>> _loadPermissions() async {
    if (widget.session.roleId == DefaultAccessRoles.adminId) {
      return const AppSuccess(<String>{});
    }
    final result = await serviceLocator<SupabaseAdminRepository>()
        .getPermissionCodesForRole(widget.session.roleId);
    return result.when(
      success: (codes) => AppSuccess(codes.toSet()),
      failure: AppFailureResult.new,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppResult<Set<String>>>(
      future: _permissions,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!.when(
          failure: (failure) => Scaffold(
            body: Center(child: Text(failure.message)),
          ),
          success: (permissions) {
            final isAdmin = widget.session.roleId == DefaultAccessRoles.adminId;
            final destinations = _destinations
                .where((item) {
                  if (item.id == 'home') return true;
                  final required = RouteAccess.anyPermissionsFor(item.route);
                  return isAdmin ||
                      required.any(
                        (permission) => permissions.contains(permission),
                      );
                })
                .toList(growable: false);
            return Theme(
              data: BackofficeTheme.executiveIvory,
              child: BackofficeWorkspace(
                items: destinations,
                initialItemId: 'home',
                onSignOut: () =>
                    context.read<AuthBloc>().add(const AuthSignOutRequested()),
                pageBuilder: (context, item) {
                  // Reuse the real router guards; sidebar visibility alone
                  // is never treated as authorization.
                  return guardedBackofficePage(item.route);
                },
              ),
            );
          },
        );
      },
    );
  }
}
