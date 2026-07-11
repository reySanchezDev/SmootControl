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
import 'package:smoo_control/features/reports/domain/entities/daily_sales_report.dart';
import 'package:smoo_control/features/reports/domain/entities/expenses_report.dart';
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
                icon: Icons.analytics_outlined,
                routeName: AppRoutes.reportSummary,
                subtitle:
                    'Resumen general de ventas, caja, gastos y productos.',
                title: 'Resumen general',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _ReportsSection(
            title: 'Gastos',
            children: [
              _ReportOptionCard(
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

class _ReportsSection extends StatelessWidget {
  const _ReportsSection({
    required this.children,
    required this.title,
  });

  final List<Widget> children;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: AppText(title, variant: AppTextVariant.titleMedium),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final columns = constraints.maxWidth >= 720 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final child in children)
                    SizedBox(width: width, child: child),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReportOptionCard extends StatelessWidget {
  const _ReportOptionCard({
    required this.icon,
    required this.routeName,
    required this.subtitle,
    required this.title,
  });

  final IconData icon;
  final String routeName;
  final String subtitle;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(routeName),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(title, variant: AppTextVariant.titleMedium),
                    const SizedBox(height: 4),
                    AppText(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      variant: AppTextVariant.label,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
