part of 'payroll_payments_report_page.dart';

class _PayrollReceiptFilters extends StatefulWidget {
  const _PayrollReceiptFilters({
    required this.cut,
    required this.employeeFilter,
    required this.from,
    required this.onChanged,
    required this.to,
  });

  final PayrollReceiptCut cut;
  final String employeeFilter;
  final DateTime from;
  final void Function({
    required DateTime from,
    required DateTime to,
    required PayrollReceiptCut cut,
    required String employeeFilter,
  })
  onChanged;
  final DateTime to;

  @override
  State<_PayrollReceiptFilters> createState() => _PayrollReceiptFiltersState();
}

class _PayrollReceiptFiltersState extends State<_PayrollReceiptFilters> {
  late final _employee = TextEditingController(text: widget.employeeFilter);

  @override
  void dispose() {
    _employee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          DropdownButtonFormField<PayrollReceiptCut>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Corte',
            ),
            initialValue: widget.cut,
            items: [
              for (final cut in PayrollReceiptCut.values)
                DropdownMenuItem(value: cut, child: AppText(cut.label)),
            ],
            onChanged: (cut) => _emit(cut: cut ?? widget.cut),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _employee,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Empleado',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => _emit(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: AppText('Desde ${_date(widget.from)}'),
                  onPressed: () => unawaited(_pick(isFrom: true)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: AppText('Hasta ${_date(widget.to)}'),
                  onPressed: () => unawaited(_pick(isFrom: false)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const AppText('Recargar'),
            onPressed: _emit,
          ),
        ],
      ),
    );
  }

  Future<void> _pick({required bool isFrom}) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      initialDate: isFrom ? widget.from : widget.to,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    _emit(
      from: isFrom ? selected : widget.from,
      to: isFrom ? widget.to : selected,
    );
  }

  void _emit({
    DateTime? from,
    DateTime? to,
    PayrollReceiptCut? cut,
  }) {
    widget.onChanged(
      from: from ?? widget.from,
      to: to ?? widget.to,
      cut: cut ?? widget.cut,
      employeeFilter: _employee.text,
    );
  }
}

class _PayrollReceiptSummary extends StatelessWidget {
  const _PayrollReceiptSummary({required this.receipts});

  final List<PayrollPaymentReceipt> receipts;

  @override
  Widget build(BuildContext context) {
    final paid = _sum((receipt) => receipt.paymentAmountInCents);
    final overtime = _sum((receipt) => receipt.overtimeInCents);
    final consumption = _sum((receipt) => receipt.consumptionInCents);
    final advance = _sum((receipt) => receipt.advanceDeductionInCents);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _SummaryChip(label: 'Pagos', value: receipts.length.toString()),
            _SummaryChip(label: 'Pagado', value: MoneyFormatter.format(paid)),
            _SummaryChip(
              label: 'Horas extras',
              value: MoneyFormatter.format(overtime),
            ),
            _SummaryChip(
              label: 'Consumo',
              value: MoneyFormatter.format(consumption),
            ),
            _SummaryChip(
              label: 'Adelantos',
              value: MoneyFormatter.format(advance),
            ),
          ],
        ),
      ),
    );
  }

  int _sum(int Function(PayrollPaymentReceipt) value) {
    return receipts.fold(0, (total, receipt) => total + value(receipt));
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 136),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(label, variant: AppTextVariant.label),
          AppText(value, variant: AppTextVariant.titleMedium),
        ],
      ),
    );
  }
}

class _PayrollReceiptCard extends StatelessWidget {
  const _PayrollReceiptCard({
    required this.onDelete,
    required this.onPdf,
    required this.onTap,
    required this.receipt,
  });

  final VoidCallback? onDelete;
  final VoidCallback onPdf;
  final VoidCallback onTap;
  final PayrollPaymentReceipt receipt;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.payments_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      receipt.employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      variant: AppTextVariant.titleMedium,
                    ),
                    AppText(
                      '${receipt.periodLabel} - ${_date(receipt.paidAt)}',
                      variant: AppTextVariant.label,
                    ),
                    AppText(_paidLabel(receipt), variant: AppTextVariant.label),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: onPdf,
                tooltip: 'PDF esquela',
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                  tooltip: 'Eliminar pago',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _date(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

String _paidLabel(PayrollPaymentReceipt receipt) {
  return 'Pagado ${MoneyFormatter.format(receipt.paymentAmountInCents)}';
}
