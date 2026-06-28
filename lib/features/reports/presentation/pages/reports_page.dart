import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/reports/domain/entities/report_period.dart';
import 'package:smoo_control/features/reports/domain/entities/report_summary.dart';
import 'package:smoo_control/features/reports/domain/services/report_summary_pdf_service.dart';
import 'package:smoo_control/features/reports/presentation/bloc/reports_bloc.dart';
import 'package:smoo_control/features/reports/presentation/bloc/reports_event.dart';
import 'package:smoo_control/features/reports/presentation/bloc/reports_state.dart';
import 'package:smoo_control/features/reports/presentation/widgets/report_period_selector.dart';
import 'package:smoo_control/features/reports/presentation/widgets/report_summary_view.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Business reports page.
class ReportsPage extends StatelessWidget {
  /// Creates the reports page.
  const ReportsPage({super.key});

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

class _ReportsContent extends StatelessWidget {
  const _ReportsContent({
    required this.period,
    required this.selectedDate,
    this.child,
    this.rangeFrom,
    this.rangeTo,
    this.summary,
  });

  final Widget? child;
  final ReportPeriod period;
  final DateTime? rangeFrom;
  final DateTime? rangeTo;
  final DateTime selectedDate;
  final ReportSummary? summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReportPeriodSelector(
          period: period,
          rangeFrom: summary?.from ?? rangeFrom,
          rangeTo: summary?.to ?? rangeTo,
          selectedDate: selectedDate,
          onChanged: (period, selectedDate, customRange) {
            context.read<ReportsBloc>().add(
              ReportsSummaryRequested(
                period: period,
                now: selectedDate,
                customRange: customRange,
              ),
            );
          },
        ),
        Expanded(
          child:
              child ??
              (summary == null
                  ? const AppLoadingPage()
                  : ReportSummaryView(summary: summary!)),
        ),
      ],
    );
  }
}
