import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/core/navigation/route_access.dart';
import 'package:smoo_control/core/responsive/responsive_breakpoints.dart';
import 'package:smoo_control/core/responsive/responsive_builder.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/features/roles/domain/repositories/i_roles_repository.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Initial responsive dashboard while the V1 modules are scaffolded.
class DashboardPage extends StatelessWidget {
  /// Creates the dashboard page.
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<AppResult<_DashboardAccess>>(
      future: _loadAccess(),
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result == null) return const AppLoadingPage();

        return result.when(
          success: (access) => _DashboardContent(access: access),
          failure: (failure) => AppEmptyState(
            icon: Icons.lock_outline,
            message: failure.message,
            title: l10n.accessDeniedTitle,
          ),
        );
      },
    );
  }

  Future<AppResult<_DashboardAccess>> _loadAccess() async {
    final session = serviceLocator<CurrentOperatorService>().session;
    if (session == null) {
      return const AppSuccess(_DashboardAccess());
    }
    if (session.roleId == DefaultAccessRoles.adminId) {
      return const AppSuccess(_DashboardAccess(isAdmin: true));
    }

    final result = await serviceLocator<IRolesRepository>()
        .getPermissionCodesForRole(session.roleId);

    return result.when(
      success: (codes) => AppSuccess(
        _DashboardAccess(permissionCodes: codes.toSet()),
      ),
      failure: AppFailureResult.new,
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.access});

  final _DashboardAccess access;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final modules = _modules(l10n).where((module) {
      return access.canOpen(module.route);
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: ResponsiveBuilder(
          builder: (context, size) {
            final isMobile = size == ResponsiveSize.mobile;
            final horizontalPadding = isMobile ? 16.0 : 32.0;

            return ListView(
              padding: EdgeInsets.all(horizontalPadding),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppText(
                        l10n.dashboardTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        variant: AppTextVariant.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      icon: Icons.logout,
                      label: l10n.signOutAction,
                      onPressed: () {
                        context.read<AuthBloc>().add(
                          const AuthSignOutRequested(),
                        );
                      },
                      primary: false,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  runSpacing: 12,
                  spacing: 12,
                  children: [
                    if (access.canOpen(AppRoutes.pos))
                      AppButton(
                        icon: Icons.point_of_sale,
                        label: l10n.primaryAction,
                        onPressed: () {
                          unawaited(
                            Navigator.of(context).pushNamed(AppRoutes.pos),
                          );
                        },
                      ),
                    if (access.canOpen(AppRoutes.reports))
                      AppButton(
                        icon: Icons.bar_chart,
                        label: l10n.secondaryAction,
                        onPressed: () {
                          unawaited(
                            Navigator.of(context).pushNamed(AppRoutes.reports),
                          );
                        },
                        primary: false,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (modules.isEmpty)
                  AppEmptyState(
                    icon: Icons.lock_outline,
                    message: l10n.accessDeniedMessage,
                    title: l10n.accessDeniedTitle,
                  )
                else
                  _DashboardGrid(
                    cards: [
                      for (final module in modules)
                        _ModuleTile(
                          icon: module.icon,
                          label: module.label,
                          route: module.route,
                        ),
                    ],
                    size: size,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<_ModuleDefinition> _modules(AppLocalizations l10n) {
    return [
      _ModuleDefinition(
        icon: Icons.category_outlined,
        label: l10n.moduleCatalog,
        route: AppRoutes.catalog,
      ),
      _ModuleDefinition(
        icon: Icons.local_cafe_outlined,
        label: l10n.moduleProducts,
        route: AppRoutes.products,
      ),
      const _ModuleDefinition(
        icon: Icons.inventory_2_outlined,
        label: 'Inventario',
        route: AppRoutes.inventory,
      ),
      const _ModuleDefinition(
        icon: Icons.takeout_dining_outlined,
        label: 'Empaques',
        route: AppRoutes.packaging,
      ),
      _ModuleDefinition(
        icon: Icons.tune_outlined,
        label: l10n.moduleModifiers,
        route: AppRoutes.modifiers,
      ),
      _ModuleDefinition(
        icon: Icons.payments_outlined,
        label: l10n.modulePaymentMethods,
        route: AppRoutes.paymentMethods,
      ),
      _ModuleDefinition(
        icon: Icons.table_restaurant_outlined,
        label: l10n.moduleTables,
        route: AppRoutes.tables,
      ),
      _ModuleDefinition(
        icon: Icons.receipt_long_outlined,
        label: l10n.moduleSales,
        route: AppRoutes.sales,
      ),
      _ModuleDefinition(
        icon: Icons.request_quote_outlined,
        label: l10n.moduleExpenses,
        route: AppRoutes.expenses,
      ),
      _ModuleDefinition(
        icon: Icons.settings_outlined,
        label: l10n.moduleSettings,
        route: AppRoutes.settings,
      ),
      _ModuleDefinition(
        icon: Icons.currency_exchange,
        label: l10n.moduleExchangeRates,
        route: AppRoutes.exchangeRates,
      ),
      _ModuleDefinition(
        icon: Icons.admin_panel_settings_outlined,
        label: l10n.moduleRoles,
        route: AppRoutes.roles,
      ),
      _ModuleDefinition(
        icon: Icons.people_outline,
        label: l10n.moduleUsers,
        route: AppRoutes.users,
      ),
      _ModuleDefinition(
        icon: Icons.manage_search_outlined,
        label: l10n.moduleAudit,
        route: AppRoutes.audit,
      ),
      _ModuleDefinition(
        icon: Icons.cloud_sync_outlined,
        label: l10n.moduleSync,
        route: AppRoutes.sync,
      ),
      const _ModuleDefinition(
        icon: Icons.cleaning_services_outlined,
        label: 'Utilidades',
        route: AppRoutes.systemMaintenance,
      ),
    ];
  }
}

class _DashboardAccess {
  const _DashboardAccess({
    this.isAdmin = false,
    this.permissionCodes = const {},
  });

  final bool isAdmin;
  final Set<String> permissionCodes;

  bool canOpen(String route) {
    if (isAdmin) return true;

    final permissions = RouteAccess.anyPermissionsFor(route);
    if (permissions.isEmpty) return true;

    return permissions.any(permissionCodes.contains);
  }
}

class _ModuleDefinition {
  const _ModuleDefinition({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({
    required this.cards,
    required this.size,
  });

  final List<Widget> cards;
  final ResponsiveSize size;

  @override
  Widget build(BuildContext context) {
    final columns = switch (size) {
      ResponsiveSize.mobile => 1,
      ResponsiveSize.tablet => 2,
      ResponsiveSize.desktop => 3,
    };

    return GridView.count(
      childAspectRatio: size == ResponsiveSize.mobile ? 1.6 : 1.35,
      crossAxisCount: columns,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: cards,
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).pushNamed(route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(height: 12),
              AppText(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                variant: AppTextVariant.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
