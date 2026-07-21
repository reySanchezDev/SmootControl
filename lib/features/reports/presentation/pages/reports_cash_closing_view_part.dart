part of 'reports_page.dart';

class _CashClosingReportView extends StatelessWidget {
  const _CashClosingReportView({
    required this.onPdfRequested,
    required this.report,
  });

  final ValueChanged<CashClosingSessionReport> onPdfRequested;
  final CashClosingReport report;

  @override
  Widget build(BuildContext context) {
    if (report.sessions.isEmpty) {
      return const AppEmptyState(
        icon: Icons.point_of_sale_outlined,
        message: 'No hay cajas registradas en el rango seleccionado.',
        title: 'Sin cierres',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final session in report.sessions)
          _CashClosingSessionCard(
            onPdfRequested: onPdfRequested,
            session: session,
          ),
      ],
    );
  }
}

class _CashClosingSessionCard extends StatelessWidget {
  const _CashClosingSessionCard({
    required this.onPdfRequested,
    required this.session,
  });

  final ValueChanged<CashClosingSessionReport> onPdfRequested;
  final CashClosingSessionReport session;

  @override
  Widget build(BuildContext context) {
    final difference = session.differenceInCents;
    final colorScheme = Theme.of(context).colorScheme;
    final diffColor = !session.hasPhysicalCount
        ? colorScheme.secondary
        : difference == 0
        ? colorScheme.primary
        : difference > 0
        ? colorScheme.tertiary
        : colorScheme.error;
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.point_of_sale_outlined, color: diffColor),
        title: AppText(
          '${_formatDate(session.businessDate)} | ${session.cashierName}',
          variant: AppTextVariant.titleMedium,
        ),
        subtitle: Text('${session.deviceName} - ${session.status}'),
        trailing: IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: () => onPdfRequested(session),
          tooltip: 'PDF de este arqueo',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          _ReportAmountRow(
            label: 'Efectivo inicial',
            value: MoneyFormatter.format(session.openingCashInCents),
          ),
          _ReportAmountRow(
            label: 'Ventas efectivo',
            value: MoneyFormatter.format(session.cashSalesInCents),
          ),
          _ReportAmountRow(
            label: 'Gastos de caja',
            value: MoneyFormatter.format(session.cashExpensesInCents),
          ),
          _ReportAmountRow(
            label: 'Efectivo esperado',
            value: MoneyFormatter.format(session.expectedCashInCents),
          ),
          _ReportAmountRow(
            label: 'Conteo fisico',
            value: session.hasPhysicalCount
                ? MoneyFormatter.format(session.physicalCashInCents)
                : 'Pendiente',
          ),
          _ReportAmountRow(
            label: 'Diferencia',
            value: session.hasPhysicalCount
                ? MoneyFormatter.format(difference)
                : 'Pendiente',
          ),
          const Divider(height: 18),
          _ReportAmountRow(
            label: 'Transferencias',
            value: MoneyFormatter.format(session.transferSalesInCents),
          ),
          _ReportAmountRow(
            label: 'Total ventas global',
            value: MoneyFormatter.format(session.totalSalesInCents),
          ),
          if (session.methodTotals.isNotEmpty) ...[
            const Divider(height: 18),
            _CashClosingMethodDetails(session: session),
          ],
          if (session.cashExpenses.isNotEmpty) ...[
            const SizedBox(height: 10),
            _CashClosingExpenseList(session: session),
          ],
        ],
      ),
    );
  }
}

class _CashClosingMethodDetails extends StatelessWidget {
  const _CashClosingMethodDetails({required this.session});

  final CashClosingSessionReport session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          'Detalle por metodo de pago',
          variant: AppTextVariant.titleMedium,
        ),
        const SizedBox(height: 6),
        for (final method in session.methodTotals)
          _ReportAmountRow(
            label: method.name,
            value: MoneyFormatter.format(method.amountInCents),
          ),
      ],
    );
  }
}

class _CashClosingExpenseList extends StatelessWidget {
  const _CashClosingExpenseList({required this.session});

  final CashClosingSessionReport session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText('Gastos de caja', variant: AppTextVariant.titleMedium),
        const SizedBox(height: 6),
        for (final expense in session.cashExpenses)
          _ReportAmountRow(
            label: '${expense.categoryName} - ${expense.description}',
            value: MoneyFormatter.format(expense.amountInCents),
          ),
      ],
    );
  }
}
