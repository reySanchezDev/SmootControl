import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/reports/data/services/supabase_daily_sales_report_service.dart';
import 'package:smoo_control/features/reports/data/services/supabase_expenses_report_service.dart';
import 'package:smoo_control/features/reports/data/services/supabase_product_performance_report_service.dart';
import 'package:smoo_control/features/reports/domain/entities/daily_sales_report.dart';
import 'package:smoo_control/features/reports/domain/entities/expenses_report.dart';
import 'package:smoo_control/features/reports/domain/entities/product_performance_report.dart';
import 'package:smoo_control/features/reports/domain/entities/report_period.dart';
import 'package:smoo_control/features/reports/domain/entities/report_summary.dart';
import 'package:smoo_control/features/reports/domain/services/report_summary_pdf_service.dart';
import 'package:smoo_control/features/reports/presentation/bloc/reports_bloc.dart';
import 'package:smoo_control/features/reports/presentation/bloc/reports_event.dart';
import 'package:smoo_control/features/reports/presentation/bloc/reports_state.dart';
import 'package:smoo_control/features/reports/presentation/widgets/report_period_selector.dart';
import 'package:smoo_control/features/reports/presentation/widgets/report_summary_view.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'reports_daily_filter_part.dart';
part 'reports_daily_page_part.dart';
part 'reports_daily_view_part.dart';
part 'reports_expenses_page_part.dart';
part 'reports_expenses_view_part.dart';
part 'reports_menu_widgets_part.dart';
part 'reports_product_performance_filters_part.dart';
part 'reports_product_performance_page_part.dart';
part 'reports_product_performance_view_part.dart';
part 'reports_shared_part.dart';

/// Business reports page.
class ReportsPage extends StatelessWidget {
  /// Creates the reports page.
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPageScaffold(
      title: 'Reportes',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _ReportsSection(
            title: 'Ventas',
            children: [
              _ReportOptionCard(
                icon: Icons.calendar_month_outlined,
                routeName: AppRoutes.dailySalesReport,
                subtitle:
                    'Ventas, costos y utilidad bruta agrupados por fecha.',
                title: 'Ventas al dia',
              ),
              _ReportOptionCard(
                icon: Icons.restaurant_menu_outlined,
                routeName: AppRoutes.productPerformanceReport,
                subtitle:
                    'Productos mas vendidos, mas rentables y oportunidades.',
                title: 'Desempeno de productos',
              ),
              _ReportOptionCard(
                icon: Icons.analytics_outlined,
                routeName: AppRoutes.reportSummary,
                subtitle:
                    'Resumen general de ventas, caja, gastos y productos.',
                title: 'Resumen general',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ReportsSection(
            title: 'Gastos',
            children: [
              _ReportOptionCard(
                icon: Icons.balance_outlined,
                routeName: AppRoutes.monthlyOperationalReport,
                subtitle: l10n.monthlyOperationalReportSubtitle,
                title: l10n.monthlyOperationalReportTitle,
              ),
              const _ReportOptionCard(
                icon: Icons.receipt_long_outlined,
                routeName: AppRoutes.expensesReport,
                subtitle:
                    'Gastos operativos por dia y categoria para decidir '
                    'donde ajustar.',
                title: 'Gastos al dia',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ReportsSection(
            title: 'Inventario',
            children: [
              _ReportOptionCard(
                icon: Icons.inventory_2_outlined,
                routeName: AppRoutes.inventoryValueReport,
                subtitle: l10n.inventoryValueReportSubtitle,
                title: l10n.inventoryValueReportTitle,
              ),
              const _ReportOptionCard(
                icon: Icons.warning_amber_outlined,
                routeName: AppRoutes.negativeInventoryReport,
                subtitle:
                    'Materias primas bajo cero por recetas y compras '
                    'pendientes de registrar.',
                title: 'Inventario negativo',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _ReportsSection(
            title: 'Planilla',
            children: [
              _ReportOptionCard(
                icon: Icons.payments_outlined,
                routeName: AppRoutes.payrollPaymentsReport,
                subtitle:
                    'Historial de pagos, esquelas y reporte formal '
                    'de planilla.',
                title: 'Planillas pagadas',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Original general report summary page.
class ReportSummaryPage extends StatelessWidget {
  /// Creates the report summary page.
  const ReportSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) => serviceLocator<ReportsBloc>()
        ..add(
          ReportsSummaryRequested(
            period: ReportPeriod.today,
            now: DateTime.now(),
          ),
        ),
      child: AppPageScaffold(
        actions: [
          BlocBuilder<ReportsBloc, ReportsState>(
            builder: (context, state) {
              final summary = state is ReportsLoaded ? state.summary : null;
              return IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: summary == null
                    ? null
                    : () => unawaited(_shareReport(summary)),
                tooltip: l10n.generatePdfAction,
              );
            },
          ),
        ],
        title: l10n.secondaryAction,
        body: BlocBuilder<ReportsBloc, ReportsState>(
          builder: (context, state) {
            return switch (state) {
              ReportsInitial() => const AppLoadingPage(),
              ReportsLoading(:final period, :final customRange) =>
                _ReportsContent(
                  period: period,
                  rangeFrom: customRange?.from,
                  rangeTo: customRange?.to,
                  selectedDate: customRange?.from ?? DateTime.now(),
                ),
              ReportsFailure(
                :final period,
                :final failure,
                :final customRange,
              ) =>
                _ReportsContent(
                  period: period,
                  rangeFrom: customRange?.from,
                  rangeTo: customRange?.to,
                  selectedDate: customRange?.from ?? DateTime.now(),
                  child: AppEmptyState(
                    icon: Icons.error_outline,
                    message: failure.message,
                    title: l10n.secondaryAction,
                  ),
                ),
              ReportsLoaded(:final period, :final summary) => _ReportsContent(
                period: period,
                selectedDate: summary.from,
                summary: summary,
              ),
            };
          },
        ),
      ),
    );
  }

  Future<void> _shareReport(ReportSummary summary) async {
    final bytes = await const ReportSummaryPdfService().buildPdf(summary);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'reporte-${_fileDate(summary.from)}.pdf',
    );
  }

  String _fileDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${date.year}${twoDigits(date.month)}${twoDigits(date.day)}';
  }
}
