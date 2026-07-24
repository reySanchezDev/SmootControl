part of 'payroll_payment_pdf_service.dart';

extension _PayrollPaymentPdfDetails on PayrollPaymentPdfService {
  List<List<String>> _consumptionRows(PayrollPaymentReceipt receipt) {
    if (receipt.consumptions.isEmpty && receipt.consumptionInCents > 0) {
      return [
        [
          _date(receipt.paidAt),
          'Consumo aplicado',
          MoneyFormatter.format(receipt.consumptionInCents),
          '-',
        ],
      ];
    }
    return [
      for (final item in receipt.consumptions)
        [
          _date(item.date),
          item.receipt,
          MoneyFormatter.format(item.amountInCents),
          '-',
        ],
    ];
  }

  List<List<String>> _rawConsumptionRows(PayrollPaymentReceipt receipt) {
    if (receipt.rawMaterialConsumptions.isEmpty &&
        receipt.rawMaterialConsumptionInCents > 0) {
      return [
        [
          _date(receipt.paidAt),
          'Materia prima aplicada',
          MoneyFormatter.format(receipt.rawMaterialConsumptionInCents),
          '-',
        ],
      ];
    }
    return [
      for (final item in receipt.rawMaterialConsumptions)
        [
          _date(item.date),
          item.receipt,
          MoneyFormatter.format(item.amountInCents),
          '-',
        ],
    ];
  }

  List<List<String>> _overtimeRows(PayrollPaymentReceipt receipt) {
    if (receipt.overtimeEntries.isEmpty && receipt.overtimeInCents > 0) {
      return [
        [
          _date(receipt.paidAt),
          'Horas extras',
          MoneyFormatter.format(receipt.overtimeInCents),
          '-',
        ],
      ];
    }
    return [
      for (final item in receipt.overtimeEntries)
        [
          _date(item.date),
          '${item.hours} h x ${MoneyFormatter.format(item.hourRateInCents)}',
          MoneyFormatter.format(item.amountInCents),
          item.note ?? '-',
        ],
    ];
  }

  List<List<String>> _advanceRows(PayrollPaymentReceipt receipt) {
    if (receipt.advances.isEmpty && receipt.advanceDeductionInCents > 0) {
      return [
        [
          _date(receipt.paidAt),
          'Adelanto aplicado',
          MoneyFormatter.format(receipt.advanceDeductionInCents),
          MoneyFormatter.format(receipt.advanceBalanceAfterInCents),
        ],
      ];
    }
    return [
      for (final item in receipt.advances)
        [
          _date(item.deliveredAt),
          MoneyFormatter.format(item.originalAmountInCents),
          MoneyFormatter.format(item.appliedAmountInCents),
          MoneyFormatter.format(item.balanceAfterInCents),
        ],
    ];
  }
}
