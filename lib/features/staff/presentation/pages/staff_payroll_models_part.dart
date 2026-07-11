part of 'staff_admin_pages.dart';

class _PayrollPayRequest {
  _PayrollPayRequest({required this.entry});

  final _PayrollEntry entry;
  int paymentAmountInCents = 0;
}

class _PayrollEntry {
  const _PayrollEntry({
    required this.employeeId,
    required this.employeeName,
    required this.periodStart,
    required this.periodEnd,
    required this.periodLabel,
    required this.baseSalaryInCents,
    required this.consumptionInCents,
    required this.advanceBalanceInCents,
    required this.advanceDeductionInCents,
    required this.advanceRemainingInCents,
    required this.canEditAdvanceDeduction,
    required this.netPayInCents,
    required this.paidInCents,
    required this.balanceInCents,
  });

  factory _PayrollEntry.fromPendingLine(
    PayrollPendingLine line, {
    required int remainingAdvanceInCents,
  }) {
    final advanceDeduction = line.salaryAdvanceDeductionInCents;
    return _PayrollEntry(
      employeeId: line.employeeId,
      employeeName: line.employeeName,
      periodStart: line.periodStart,
      periodEnd: line.periodEnd,
      periodLabel: line.periodLabel,
      baseSalaryInCents: line.baseSalaryInCents,
      consumptionInCents: line.consumptionInCents,
      advanceBalanceInCents: advanceDeduction + remainingAdvanceInCents,
      advanceDeductionInCents: advanceDeduction,
      advanceRemainingInCents: remainingAdvanceInCents,
      canEditAdvanceDeduction: false,
      netPayInCents: line.netPayInCents,
      paidInCents: line.paidInCents,
      balanceInCents: line.balanceInCents,
    );
  }

  final String employeeId;
  final String employeeName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String periodLabel;
  final int baseSalaryInCents;
  final int consumptionInCents;
  final int advanceBalanceInCents;
  final int advanceDeductionInCents;
  final int advanceRemainingInCents;
  final bool canEditAdvanceDeduction;
  final int netPayInCents;
  final int paidInCents;
  final int balanceInCents;

  int payableBalanceFor(int advanceDeductionInCents) {
    if (!canEditAdvanceDeduction) return balanceInCents;
    final safeDeduction = advanceDeductionInCents.clamp(
      0,
      advanceBalanceInCents,
    );
    final balance = baseSalaryInCents - consumptionInCents - safeDeduction;
    return balance < 0 ? 0 : balance;
  }
}

class _PayrollPeriod {
  const _PayrollPeriod({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;
}

class _PayrollRow extends StatelessWidget {
  const _PayrollRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final int value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong ? Theme.of(context).textTheme.titleMedium : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(_money(value), style: style),
        ],
      ),
    );
  }
}

class _PayrollSectionHeader extends StatelessWidget {
  const _PayrollSectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

String _money(int cents) => 'C\$ ${(cents / 100).toStringAsFixed(2)}';

_PayrollPeriod _currentPayrollPeriod(DateTime now) {
  final firstHalf = now.day <= 15;
  final start = DateTime(now.year, now.month, firstHalf ? 1 : 16);
  final end = firstHalf
      ? DateTime(now.year, now.month, 15)
      : DateTime(now.year, now.month + 1, 0);
  final half = firstHalf ? 'Primera quincena' : 'Segunda quincena';
  return _PayrollPeriod(
    start: start,
    end: end,
    label: '$half de ${_monthName(now.month)} ${now.year}',
  );
}

String _monthName(int month) {
  return const [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ][month - 1];
}

String _dateOnly(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isBeforeDate(DateTime value, DateTime limit) {
  return DateTime(value.year, value.month, value.day).isBefore(
    DateTime(limit.year, limit.month, limit.day),
  );
}

bool _isAfterDate(DateTime value, DateTime limit) {
  return DateTime(value.year, value.month, value.day).isAfter(
    DateTime(limit.year, limit.month, limit.day),
  );
}

String _date(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

String? _optional(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

Future<bool> _confirmPermanentDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => Navigator.of(context).pop(true),
          label: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return result ?? false;
}
