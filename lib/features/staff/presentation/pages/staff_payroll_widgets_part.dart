part of 'staff_admin_pages.dart';

class _PayrollDraftList extends StatelessWidget {
  const _PayrollDraftList({
    required this.advances,
    required this.consumptions,
    required this.employees,
    required this.overtimeEntries,
    required this.pendingLines,
    required this.period,
    required this.onPay,
  });

  final List<SalaryAdvance> advances;
  final List<StaffConsumption> consumptions;
  final List<Employee> employees;
  final List<EmployeeOvertimeEntry> overtimeEntries;
  final List<PayrollPendingLine> pendingLines;
  final _PayrollPeriod period;
  final ValueChanged<_PayrollPayRequest> onPay;

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    if (entries.isEmpty) {
      return const AppEmptyState(
        icon: Icons.summarize_outlined,
        title: 'Sin pagos pendientes',
        message: 'Todos los empleados estan pagados para este periodo.',
      );
    }
    return ListView.separated(
      itemCount: entries.length + 1,
      padding: const EdgeInsets.all(12),
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return ListTile(
            leading: const Icon(Icons.date_range_outlined),
            title: Text(period.label),
            subtitle: Text(
              '${_dateOnly(period.start)} - ${_dateOnly(period.end)}',
            ),
          );
        }
        final entry = entries[index - 1];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.periodLabel} | ${entry.employeeName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                const _PayrollSectionHeader('Nomina'),
                _PayrollRow(
                  label: 'Salario',
                  value: entry.baseSalaryInCents,
                ),
                _PayrollRow(
                  label: 'Horas extras',
                  value: entry.overtimeInCents,
                ),
                _PayrollRow(label: 'Consumo', value: entry.consumptionInCents),
                _PayrollRow(
                  label: entry.canEditAdvanceDeduction
                      ? 'Neto antes de adelanto'
                      : 'Neto planilla',
                  value: entry.netPayInCents,
                ),
                if (entry.paidInCents > 0)
                  _PayrollRow(label: 'Pagado', value: entry.paidInCents),
                const Divider(),
                const _PayrollSectionHeader('Adelantos del empleado'),
                _PayrollRow(
                  label: entry.canEditAdvanceDeduction
                      ? 'Adelanto pendiente'
                      : 'Adelanto registrado',
                  value: entry.advanceBalanceInCents,
                ),
                if (!entry.canEditAdvanceDeduction ||
                    entry.advanceDeductionInCents > 0)
                  _PayrollRow(
                    label: 'Abono a adelanto',
                    value: entry.advanceDeductionInCents,
                  ),
                if (!entry.canEditAdvanceDeduction &&
                    entry.advanceRemainingInCents > 0)
                  _PayrollRow(
                    label: 'Saldo adelanto',
                    value: entry.advanceRemainingInCents,
                  ),
                const Divider(),
                _PayrollRow(
                  label: 'Por pagar de nomina',
                  value: entry.balanceInCents,
                  strong: true,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => onPay(
                      _PayrollPayRequest(
                        entry: entry,
                      ),
                    ),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Pagar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_PayrollEntry> _entries() {
    final consumptionByEmployee = <String, int>{};
    for (final consumption in consumptions.where((item) {
      return item.payrollRunId == null &&
          !_isBeforeDate(item.createdAt, period.start) &&
          !_isAfterDate(item.createdAt, period.end);
    })) {
      consumptionByEmployee.update(
        consumption.employeeId,
        (current) => current + consumption.totalInCents,
        ifAbsent: () => consumption.totalInCents,
      );
    }
    final advancesByEmployee = <String, int>{};
    for (final advance in advances.where((item) {
      return item.status == 'pending' || item.status == 'partially_paid';
    })) {
      final balance = advance.balanceInCents ?? advance.amountInCents;
      advancesByEmployee.update(
        advance.employeeId,
        (current) => current + balance,
        ifAbsent: () => balance,
      );
    }
    final overtimeByEmployee = <String, int>{};
    for (final entry in overtimeEntries.where((item) {
      return item.status == 'pending' &&
          !_isBeforeDate(item.workedDate, period.start) &&
          !_isAfterDate(item.workedDate, period.end);
    })) {
      overtimeByEmployee.update(
        entry.employeeId,
        (current) => current + entry.totalInCents,
        ifAbsent: () => entry.totalInCents,
      );
    }

    final entries = <_PayrollEntry>[
      for (final line in pendingLines.where(_hasPayrollBalance))
        _PayrollEntry.fromPendingLine(
          line,
          remainingAdvanceInCents: advancesByEmployee[line.employeeId] ?? 0,
        ),
    ];
    final postedCurrentEmployeeIds = {
      for (final line in pendingLines.where((line) {
        return _sameDate(line.periodStart, period.start) &&
            _sameDate(line.periodEnd, period.end);
      }))
        line.employeeId,
    };
    for (final employee in employees) {
      if (!employee.isActive ||
          postedCurrentEmployeeIds.contains(employee.id)) {
        continue;
      }
      final consumption = consumptionByEmployee[employee.id] ?? 0;
      final overtime = overtimeByEmployee[employee.id] ?? 0;
      final advance = advancesByEmployee[employee.id] ?? 0;
      final balance = employee.baseSalaryInCents + overtime - consumption;
      if (balance <= 0) continue;
      entries.add(
        _PayrollEntry(
          employeeId: employee.id,
          employeeName: employee.fullName,
          periodStart: period.start,
          periodEnd: period.end,
          periodLabel: period.label,
          baseSalaryInCents: employee.baseSalaryInCents,
          consumptionInCents: consumption,
          overtimeInCents: overtime,
          advanceBalanceInCents: advance,
          advanceDeductionInCents: 0,
          advanceRemainingInCents: advance,
          canEditAdvanceDeduction: true,
          netPayInCents: balance,
          paidInCents: 0,
          balanceInCents: balance,
        ),
      );
    }
    entries.sort((a, b) {
      final periodCompare = a.periodStart.compareTo(b.periodStart);
      if (periodCompare != 0) return periodCompare;
      return a.employeeName.compareTo(b.employeeName);
    });
    return entries;
  }

  bool _hasPayrollBalance(PayrollPendingLine line) {
    if (line.balanceInCents <= 0) return false;
    return line.paidInCents + line.salaryAdvanceDeductionInCents <
        line.netPayInCents;
  }
}
