import 'dart:async';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/reports/data/services/supabase_payroll_report_service.dart';
import 'package:smoo_control/features/reports/domain/entities/payroll_payment_receipt.dart';
import 'package:smoo_control/features/reports/domain/services/payroll_payment_pdf_service.dart';

part 'payroll_payments_report_widgets_part.dart';
part 'payroll_payments_report_detail_part.dart';

/// Operating mode for the paid payroll page.
enum PayrollPaymentsPageMode {
  /// Reporting mode: read-only with PDF actions.
  report,

  /// Staff admin mode: allows reversing payroll payments.
  staffAdmin,
}

/// Historical paid payroll report with PDF actions.
class PayrollPaymentsReportPage extends StatefulWidget {
  /// Creates the page.
  const PayrollPaymentsReportPage({
    this.mode = PayrollPaymentsPageMode.report,
    super.key,
  });

  /// Controls whether destructive payroll actions are available.
  final PayrollPaymentsPageMode mode;

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

  bool get _canDelete => widget.mode == PayrollPaymentsPageMode.staffAdmin;

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
      title: _canDelete ? 'Pagos de planilla' : 'Planillas pagadas',
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
    return PayrollReceiptsCollection(
      receipts: filtered,
      canReverse: _canDelete,
      onDetails: _openDetail,
      onPdf: (receipt) => unawaited(_shareEmployeeReceipt(receipt)),
      onReverse: (receipt) => unawaited(_confirmDelete(receipt)),
      onExportAll: () => unawaited(_shareFormalReport()),
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
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    if (desktop) {
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1000,
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              child: _PayrollReceiptDetail(receipt: receipt),
            ),
          ),
        ),
      );
      return;
    }
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

  Future<void> _confirmDelete(PayrollPaymentReceipt receipt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar pago de planilla'),
        content: Text(
          'Se eliminara el pago de ${receipt.employeeName} y se reactivaran '
          'los consumos, adelantos y saldo de planilla relacionados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await _deleteReceipt(receipt);
  }

  Future<void> _deleteReceipt(PayrollPaymentReceipt receipt) async {
    final result = await _service.reverseReceipt(receipt.id);
    if (!mounted) return;
    await result.when(
      success: (_) async {
        setState(_reload);
        await showAppMessageDialog(
          context: context,
          title: 'Pago eliminado',
          message: 'La planilla quedo disponible nuevamente para pago.',
        );
      },
      failure: (error) => showAppMessageDialog(
        context: context,
        title: 'No se pudo eliminar',
        message: error.message,
      ),
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

/// Read-only payroll receipt listing; optional reverse command is staff-only.
class PayrollReceiptsCollection extends StatelessWidget {
  /// Creates the receipt listing without loading or mutating remote data.
  const PayrollReceiptsCollection({
    required this.receipts,
    required this.canReverse,
    required this.onDetails,
    required this.onPdf,
    required this.onReverse,
    required this.onExportAll,
    super.key,
  });

  /// Receipt snapshots already filtered by the owning page.
  final List<PayrollPaymentReceipt> receipts;

  /// True only when the owning page is in staff-administration mode.
  final bool canReverse;

  /// Opens the existing detail display.
  final ValueChanged<PayrollPaymentReceipt> onDetails;

  /// Generates the existing payment PDF.
  final ValueChanged<PayrollPaymentReceipt> onPdf;

  /// Delegates to the existing confirmation before any reversal.
  final ValueChanged<PayrollPaymentReceipt> onReverse;

  /// Exports the filtered complete payroll report.
  final VoidCallback onExportAll;

  @override
  Widget build(BuildContext context) {
    final filtered = receipts;
    return Column(
      children: [
        _PayrollReceiptSummary(receipts: filtered),
        Expanded(
          child: BackofficeCollectionView<PayrollPaymentReceipt>(
            items: filtered,
            rowKey: (receipt) => receipt.id,
            rowLabel: (receipt) => receipt.employeeName,
            globalActions: [
              OutlinedButton.icon(
                onPressed: onExportAll,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF planilla completa'),
              ),
            ],
            selectionActions: [
              BackofficeSelectionAction<PayrollPaymentReceipt>(
                label: 'Ver detalle',
                icon: Icons.visibility_outlined,
                onPressed: onDetails,
              ),
              BackofficeSelectionAction<PayrollPaymentReceipt>(
                label: 'PDF esquela',
                icon: Icons.picture_as_pdf_outlined,
                onPressed: onPdf,
              ),
              if (canReverse)
                BackofficeSelectionAction<PayrollPaymentReceipt>(
                  label: 'Eliminar pago',
                  icon: Icons.delete_outline,
                  destructive: true,
                  onPressed: onReverse,
                ),
            ],
            searchLabel: 'Buscar empleado, código o puesto',
            showSearch: false,
            searchTextFor: (receipt) => [
              receipt.employeeName,
              receipt.employeeCode,
              receipt.positionName,
              receipt.periodLabel,
              _date(receipt.paidAt),
              MoneyFormatter.format(receipt.paymentAmountInCents),
            ].join(' '),
            emptyTitle: 'Sin pagos',
            emptyMessage:
                'No hay planillas pagadas para el filtro seleccionado.',
            compactBuilder: (_, receipt) => ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(receipt.employeeName),
              subtitle: Text(
                '${receipt.periodLabel} · ${_date(receipt.paidAt)}',
              ),
              trailing: Text(
                MoneyFormatter.format(receipt.paymentAmountInCents),
              ),
            ),
            columns: [
              BackofficeListColumn<PayrollPaymentReceipt>(
                label: 'Empleado',
                width: 275,
                compare: (a, b) => a.employeeName.compareTo(b.employeeName),
                cell: (_, receipt) => Text(receipt.employeeName),
              ),
              BackofficeListColumn<PayrollPaymentReceipt>(
                label: 'Puesto',
                width: 200,
                compare: (a, b) => a.positionName.compareTo(b.positionName),
                cell: (_, receipt) => Text(receipt.positionName),
              ),
              BackofficeListColumn<PayrollPaymentReceipt>(
                label: 'Período',
                width: 215,
                compare: (a, b) => a.periodStart.compareTo(b.periodStart),
                cell: (_, receipt) => Text(receipt.periodLabel),
              ),
              BackofficeListColumn<PayrollPaymentReceipt>(
                label: 'Fecha de pago',
                width: 160,
                compare: (a, b) => a.paidAt.compareTo(b.paidAt),
                cell: (_, receipt) => Text(_date(receipt.paidAt)),
              ),
              BackofficeListColumn<PayrollPaymentReceipt>(
                label: 'Pagado',
                width: 175,
                alignment: Alignment.centerRight,
                compare: (a, b) =>
                    a.paymentAmountInCents.compareTo(b.paymentAmountInCents),
                cell: (_, receipt) => Text(
                  MoneyFormatter.format(receipt.paymentAmountInCents),
                ),
              ),
              BackofficeListColumn<PayrollPaymentReceipt>(
                label: 'Saldo restante',
                width: 180,
                alignment: Alignment.centerRight,
                compare: (a, b) =>
                    a.balanceAfterInCents.compareTo(b.balanceAfterInCents),
                cell: (_, receipt) => Text(
                  MoneyFormatter.format(receipt.balanceAfterInCents),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
