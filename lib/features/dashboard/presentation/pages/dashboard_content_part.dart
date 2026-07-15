part of 'dashboard_page.dart';

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.access});

  final _DashboardAccess access;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = _sections(l10n)
        .map((section) {
          return _DashboardSection(
            title: section.title,
            modules: section.modules.where((module) {
              return access.canOpen(module.route);
            }).toList(),
          );
        })
        .where((section) => section.modules.isNotEmpty)
        .toList();

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
                if (sections.isEmpty)
                  AppEmptyState(
                    icon: Icons.lock_outline,
                    message: l10n.accessDeniedMessage,
                    title: l10n.accessDeniedTitle,
                  )
                else
                  for (final section in sections) ...[
                    AppText(
                      section.title,
                      variant: AppTextVariant.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    _DashboardGrid(
                      cards: [
                        for (final module in section.modules)
                          _ModuleTile(
                            icon: module.icon,
                            label: module.label,
                            route: module.route,
                          ),
                      ],
                      size: size,
                    ),
                    const SizedBox(height: 22),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<_DashboardSection> _sections(AppLocalizations l10n) {
    return [
      _DashboardSection(
        title: 'Operacion',
        modules: [
          _ModuleDefinition(
            icon: Icons.receipt_long_outlined,
            label: l10n.moduleSales,
            route: AppRoutes.sales,
          ),
          _ModuleDefinition(
            icon: Icons.point_of_sale_outlined,
            label: l10n.moduleCashRegister,
            route: AppRoutes.cashRegisters,
          ),
          _ModuleDefinition(
            icon: Icons.request_quote_outlined,
            label: l10n.moduleExpenses,
            route: AppRoutes.expenses,
          ),
          const _ModuleDefinition(
            icon: Icons.inventory_2_outlined,
            label: 'Inventario',
            route: AppRoutes.inventory,
          ),
          const _ModuleDefinition(
            icon: Icons.manage_history_outlined,
            label: 'Movimientos inventario',
            route: AppRoutes.inventoryMovements,
          ),
          const _ModuleDefinition(
            icon: Icons.takeout_dining_outlined,
            label: 'Empaques',
            route: AppRoutes.packaging,
          ),
        ],
      ),
      _DashboardSection(
        title: 'Catalogos POS',
        modules: [
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
        ],
      ),
      const _DashboardSection(
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
            icon: Icons.history_outlined,
            label: 'Pagos planilla',
            route: AppRoutes.staffPayrollPayments,
          ),
        ],
      ),
      _DashboardSection(
        title: 'Administracion',
        modules: [
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
          const _ModuleDefinition(
            icon: Icons.rule_outlined,
            label: 'Reglas negocio',
            route: AppRoutes.businessRules,
          ),
          _ModuleDefinition(
            icon: Icons.manage_search_outlined,
            label: l10n.moduleAudit,
            route: AppRoutes.audit,
          ),
        ],
      ),
      _DashboardSection(
        title: 'Sistema',
        modules: [
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
        ],
      ),
    ];
  }
}
