part of 'payroll_payments_report_page.dart';

class _PayrollReceiptDetail extends StatelessWidget {
  const _PayrollReceiptDetail({required this.receipt});

  final PayrollPaymentReceipt receipt;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ListView(
          children: [
            AppText(receipt.employeeName, variant: AppTextVariant.titleMedium),
            AppText(receipt.periodLabel, variant: AppTextVariant.label),
            const Divider(height: 24),
            _DetailRow('Salario', receipt.baseSalaryInCents),
            _DetailRow('Consumo', receipt.consumptionInCents),
            _DetailRow('Abono adelanto', receipt.advanceDeductionInCents),
            _DetailRow('Neto planilla', receipt.netPayInCents),
            _DetailRow('Pagado', receipt.paymentAmountInCents, strong: true),
            const Divider(height: 24),
            _DetailRow('Pendiente nomina', receipt.balanceAfterInCents),
            _DetailRow('Saldo adelantos', receipt.advanceBalanceAfterInCents),
            const SizedBox(height: 12),
            _ReceiptDetailList(title: 'Consumos', rows: _consumptionRows()),
            const SizedBox(height: 12),
            _ReceiptDetailList(title: 'Adelantos', rows: _advanceRows()),
          ],
        ),
      ),
    );
  }

  List<String> _consumptionRows() {
    if (receipt.consumptions.isEmpty && receipt.consumptionInCents > 0) {
      final amount = MoneyFormatter.format(receipt.consumptionInCents);
      return [
        'Consumo aplicado - $amount',
      ];
    }
    return [
      for (final item in receipt.consumptions) _consumptionLabel(item),
    ];
  }

  List<String> _advanceRows() {
    if (receipt.advances.isEmpty && receipt.advanceDeductionInCents > 0) {
      final amount = MoneyFormatter.format(receipt.advanceDeductionInCents);
      return [
        'Abono aplicado - $amount',
      ];
    }
    return [
      for (final item in receipt.advances) _advanceLabel(item),
    ];
  }

  String _consumptionLabel(PayrollReceiptConsumption item) {
    final amount = MoneyFormatter.format(item.amountInCents);
    return '${_date(item.date)} ${item.receipt} - $amount';
  }

  String _advanceLabel(PayrollReceiptAdvance item) {
    final applied = MoneyFormatter.format(item.appliedAmountInCents);
    final balance = MoneyFormatter.format(item.balanceAfterInCents);
    return '${_date(item.deliveredAt)} abono $applied saldo $balance';
  }
}

class _ReceiptDetailList extends StatelessWidget {
  const _ReceiptDetailList({required this.rows, required this.title});

  final List<String> rows;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(title, variant: AppTextVariant.titleMedium),
        if (rows.isEmpty)
          const AppText('Sin registros', variant: AppTextVariant.label)
        else
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: AppText(row, variant: AppTextVariant.label),
            ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.strong = false});

  final String label;
  final bool strong;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: AppText(
              label,
              variant: strong
                  ? AppTextVariant.titleMedium
                  : AppTextVariant.body,
            ),
          ),
          AppText(
            MoneyFormatter.format(value),
            variant: strong ? AppTextVariant.titleMedium : AppTextVariant.body,
          ),
        ],
      ),
    );
  }
}
