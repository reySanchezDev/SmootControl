import 'dart:async';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/reports/data/services/supabase_payroll_report_service.dart';
import 'package:smoo_control/features/reports/domain/entities/payroll_payment_receipt.dart';
import 'package:smoo_control/features/reports/domain/services/payroll_payment_pdf_service.dart';

part 'payroll_payments_report_widgets_part.dart';
part 'payroll_payments_report_detail_part.dart';

/// Historical paid payroll report with PDF actions.
class PayrollPaymentsReportPage extends StatefulWidget {
  /// Creates the page.
  const PayrollPaymentsReportPage({super.key});

  @override
  State<PayrollPaymentsReportPage> createState() =>
      _PayrollPaymentsReportPageState();
}

class _PayrollPaymentsReportPageState extends State<PayrollPaymentsReportPage> {
  late Future<AppResult<List<PayrollPaymentReceipt>>> _future;
  late DateTime _from;
  late DateTime _to;
  PayrollReceiptCut _cut = PayrollReceiptCut.all;
  String _employeeFilter = '';

  SupabasePayrollReportService get _service =>
      serviceLocator<SupabasePayrollReportService>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
    _to = DateTime(now.year, now.month, now.day);
    _reload();
  }

  void _reload() {
    _future = _service.loadReceipts(from: _from, to: _to, cut: _cut);
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: () => unawaited(_shareFormalReport()),
          tooltip: 'PDF planilla completa',
        ),
      ],
      title: 'Planillas pagadas',
      body: Column(
        children: [
          _PayrollReceiptFilters(
            cut: _cut,
            employeeFilter: _employeeFilter,
            from: _from,
            onChanged: _applyFilters,
            to: _to,
          ),
          Expanded(
            child: FutureBuilder<AppResult<List<PayrollPaymentReceipt>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const AppLoadingPage();
                return snapshot.data!.when(
                  success: _buildContent,
                  failure: (error) => AppEmptyState(
                    icon: Icons.error_outline,
                    message: error.message,
                    title: 'No se pudo cargar',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<PayrollPaymentReceipt> receipts) {
    final filtered = _filter(receipts);
    if (filtered.isEmpty) {
      return const AppEmptyState(
        icon: Icons.payments_outlined,
        message: 'No hay planillas pagadas para el filtro seleccionado.',
        title: 'Sin pagos',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        if (index == 0) return _PayrollReceiptSummary(receipts: filtered);
        final receipt = filtered[index - 1];
        return _PayrollReceiptCard(
          receipt: receipt,
          onPdf: () => unawaited(_shareEmployeeReceipt(receipt)),
          onTap: () => _openDetail(receipt),
        );
      },
      itemCount: filtered.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
    );
  }

  List<PayrollPaymentReceipt> _filter(List<PayrollPaymentReceipt> receipts) {
    final query = _employeeFilter.trim().toLowerCase();
    if (query.isEmpty) return receipts;
    return receipts.where((receipt) {
      return receipt.employeeName.toLowerCase().contains(query) ||
          receipt.employeeCode.toLowerCase().contains(query) ||
          receipt.positionName.toLowerCase().contains(query);
    }).toList();
  }

  void _applyFilters({
    required DateTime from,
    required DateTime to,
    required PayrollReceiptCut cut,
    required String employeeFilter,
  }) {
    setState(() {
      _from = from;
      _to = to.isBefore(from) ? from : to;
      _cut = cut;
      _employeeFilter = employeeFilter;
      _reload();
    });
  }

  void _openDetail(PayrollPaymentReceipt receipt) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _PayrollReceiptDetail(receipt: receipt),
      ),
    );
  }

  Future<void> _shareEmployeeReceipt(PayrollPaymentReceipt receipt) async {
    final bytes = await const PayrollPaymentPdfService().buildEmployeeReceipt(
      receipt,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'esquela-${_safeName(receipt.employeeName)}.pdf',
    );
  }

  Future<void> _shareFormalReport() async {
    final result = await _future;
    if (!mounted) return;
    final receipts = switch (result) {
      AppSuccess(:final value) => _filter(value),
      AppFailureResult() => const <PayrollPaymentReceipt>[],
    };
    if (receipts.isEmpty) return;
    final bytes = await const PayrollPaymentPdfService().buildOwnerReport(
      receipts: receipts,
      from: _from,
      to: _to,
    );
    await Printing.sharePdf(bytes: bytes, filename: 'planilla-pagada.pdf');
  }

  String _safeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  }
}
