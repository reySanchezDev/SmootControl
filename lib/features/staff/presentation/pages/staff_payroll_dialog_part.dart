part of 'staff_admin_pages.dart';

class _PayrollPaymentDialog extends StatefulWidget {
  const _PayrollPaymentDialog({required this.request});

  final _PayrollPayRequest request;

  @override
  State<_PayrollPaymentDialog> createState() => _PayrollPaymentDialogState();
}

class _PayrollPaymentDialogState extends State<_PayrollPaymentDialog> {
  late final _payment = TextEditingController(
    text: (widget.request.entry.balanceInCents / 100).toStringAsFixed(2),
  );
  late final _deduction = TextEditingController(
    text: (widget.request.entry.advanceDeductionInCents / 100).toStringAsFixed(
      2,
    ),
  );
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.request.entry.canEditAdvanceDeduction) {
      _deduction.addListener(_syncPaymentWithAdvanceDeduction);
    }
  }

  @override
  void dispose() {
    _deduction.removeListener(_syncPaymentWithAdvanceDeduction);
    _payment.dispose();
    _deduction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return AlertDialog(
      title: Text('Pagar ${request.entry.employeeName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PayrollRow(
            label: 'Salario',
            value: request.entry.baseSalaryInCents,
          ),
          _PayrollRow(
            label: 'Consumo',
            value: request.entry.consumptionInCents,
          ),
          _PayrollRow(
            label: request.entry.canEditAdvanceDeduction
                ? 'Neto antes de adelanto'
                : 'Saldo nomina',
            value: request.entry.netPayInCents,
          ),
          const Divider(),
          _PayrollRow(
            label: request.entry.canEditAdvanceDeduction
                ? 'Adelanto pendiente'
                : 'Adelanto registrado',
            value: request.entry.advanceBalanceInCents,
          ),
          if (!request.entry.canEditAdvanceDeduction)
            _PayrollRow(
              label: 'Abono a adelanto aplicado',
              value: request.entry.advanceDeductionInCents,
            ),
          if (request.entry.advanceRemainingInCents > 0)
            _PayrollRow(
              label: 'Saldo adelanto',
              value: request.entry.advanceRemainingInCents,
            ),
          const Divider(),
          if (request.entry.canEditAdvanceDeduction)
            TextField(
              controller: _deduction,
              decoration: const InputDecoration(labelText: 'Abono adelanto'),
              keyboardType: TextInputType.number,
            ),
          TextField(
            controller: _payment,
            decoration: const InputDecoration(labelText: 'Monto a pagar'),
            keyboardType: TextInputType.number,
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Confirmar pago')),
      ],
    );
  }

  void _submit() {
    final payment =
        (double.tryParse(_payment.text.trim().replaceAll(',', '.')) ?? -1) *
        100;
    final paymentCents = payment.round();
    final deductionCents = widget.request.entry.canEditAdvanceDeduction
        ? ((double.tryParse(_deduction.text.trim().replaceAll(',', '.')) ??
                      -1) *
                  100)
              .round()
        : 0;
    final payableBalance = widget.request.entry.payableBalanceFor(
      deductionCents,
    );
    if (paymentCents <= 0 || paymentCents > payableBalance) {
      setState(() => _error = 'Verifica el monto a pagar.');
      return;
    }
    if (deductionCents < 0 ||
        deductionCents > widget.request.entry.advanceBalanceInCents) {
      setState(() => _error = 'Verifica el abono del adelanto.');
      return;
    }
    widget.request.paymentAmountInCents = paymentCents;
    Navigator.of(context).pop(deductionCents);
  }

  void _syncPaymentWithAdvanceDeduction() {
    final deduction = _parseCents(_deduction.text);
    if (deduction == null) return;
    final payableBalance = widget.request.entry.payableBalanceFor(deduction);
    _payment.text = (payableBalance / 100).toStringAsFixed(2);
  }

  int? _parseCents(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) return null;
    return (parsed * 100).round();
  }
}
