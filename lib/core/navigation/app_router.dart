import 'package:flutter/material.dart';
import 'package:smoo_control/core/navigation/admin_online_guard.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/core/navigation/route_access.dart';
import 'package:smoo_control/features/audit/presentation/pages/audit_log_page.dart';
import 'package:smoo_control/features/catalog/presentation/pages/catalog_page.dart';
import 'package:smoo_control/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:smoo_control/features/exchange_rates/presentation/pages/exchange_rates_page.dart';
import 'package:smoo_control/features/expenses/presentation/pages/expenses_page.dart';
import 'package:smoo_control/features/inventory/presentation/pages/inventory_page.dart';
import 'package:smoo_control/features/modifiers/presentation/pages/modifiers_page.dart';
import 'package:smoo_control/features/packaging/presentation/pages/packaging_page.dart';
import 'package:smoo_control/features/payment_methods/presentation/pages/payment_methods_page.dart';
import 'package:smoo_control/features/pos/presentation/pages/pos_page.dart';
import 'package:smoo_control/features/products/presentation/pages/products_page.dart';
import 'package:smoo_control/features/reports/presentation/pages/reports_page.dart';
import 'package:smoo_control/features/roles/presentation/pages/roles_page.dart';
import 'package:smoo_control/features/sales/presentation/pages/sales_page.dart';
import 'package:smoo_control/features/settings/presentation/pages/settings_page.dart';
import 'package:smoo_control/features/sync/presentation/pages/sync_page.dart';
import 'package:smoo_control/features/tables/presentation/pages/tables_page.dart';
import 'package:smoo_control/features/users/presentation/pages/users_page.dart';

/// Builds application routes from route names.
Route<void> onGenerateAppRoute(RouteSettings settings) {
  return MaterialPageRoute<void>(
    builder: (_) => _guardedPage(settings.name),
    settings: settings,
  );
}

Widget _guardedPage(String? routeName) {
  final page = switch (routeName) {
    AppRoutes.dashboard || null => const DashboardPage(),
    AppRoutes.pos => const PosPage(),
    AppRoutes.reports => const ReportsPage(),
    AppRoutes.catalog => const CatalogPage(),
    AppRoutes.products => const ProductsPage(),
    AppRoutes.inventory => const InventoryPage(),
    AppRoutes.packaging => const PackagingPage(),
    AppRoutes.modifiers => const ModifiersPage(),
    AppRoutes.paymentMethods => const PaymentMethodsPage(),
    AppRoutes.tables => const TablesPage(),
    AppRoutes.sales => const SalesPage(),
    AppRoutes.expenses => const ExpensesPage(),
    AppRoutes.settings => const SettingsPage(),
    AppRoutes.exchangeRates => const ExchangeRatesPage(),
    AppRoutes.roles => const RolesPage(),
    AppRoutes.users => const UsersPage(),
    AppRoutes.audit => const AuditLogPage(),
    AppRoutes.sync => const SyncPage(),
    _ => const DashboardPage(),
  };

  return RouteAccessGuard(
    anyPermissions: RouteAccess.anyPermissionsFor(routeName),
    child: _requiresOnlineAdmin(routeName)
        ? AdminOnlineGuard(child: page)
        : page,
  );
}

bool _requiresOnlineAdmin(String? routeName) {
  return switch (routeName) {
    AppRoutes.catalog ||
    AppRoutes.products ||
    AppRoutes.inventory ||
    AppRoutes.packaging ||
    AppRoutes.modifiers ||
    AppRoutes.paymentMethods ||
    AppRoutes.tables ||
    AppRoutes.sales ||
    AppRoutes.expenses ||
    AppRoutes.settings ||
    AppRoutes.exchangeRates ||
    AppRoutes.roles ||
    AppRoutes.users ||
    AppRoutes.audit ||
    AppRoutes.reports => true,
    _ => false,
  };
}
