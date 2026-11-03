part of 'staff_admin_pages.dart';

class _PayrollDraftList extends StatelessWidget {
  const _PayrollDraftList({
    required this.advances,
    required this.consumptions,
    required this.rawConsumptions,
    required this.employees,
    required this.overtimeEntries,
    required this.pendingLines,
    required this.period,
    required this.onPay,
  });

  final List<SalaryAdvance> advances;
  final List<StaffConsumption> consumptions;
  final List<RawMaterialStaffConsumption> rawConsumptions;
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
        message: 'Todos los empleados están pagados para este período.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ListTile(
            leading: const Icon(Icons.date_range_outlined),
            title: Text(period.label),
            subtitle: Text(
              '${_dateOnly(period.start)} - ${_dateOnly(period.end)}',
            ),
          ),
        ),
        Expanded(
          child: BackofficeCollectionView<_PayrollEntry>(
            items: entries,
            rowKey: (entry) =>
                '${entry.employeeId}:${entry.periodStart.toIso8601String()}:${entry.periodEnd.toIso8601String()}',
            rowLabel: (entry) => entry.employeeName,
            selectionActions: [
              BackofficeSelectionAction<_PayrollEntry>(
                label: 'Ver desglose',
                icon: Icons.receipt_long_outlined,
                onPressed: (entry) => _showBreakdown(context, entry),
              ),
              BackofficeSelectionAction<_PayrollEntry>(
                label: 'Pagar',
                icon: Icons.payments_outlined,
                onPressed: (entry) => onPay(_PayrollPayRequest(entry: entry)),
              ),
            ],
            searchLabel: 'Buscar empleado o período',
            searchTextFor: (entry) => [
              entry.employeeName,
              entry.periodLabel,
              _money(entry.balanceInCents),
              _money(entry.paidInCents),
            ].join(' '),
            emptyTitle: 'Sin coincidencias',
            emptyMessage: 'No hay empleados pendientes con ese filtro.',
            compactBuilder: (_, entry) => ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(entry.employeeName),
              subtitle: Text(entry.periodLabel),
              trailing: Text(_money(entry.balanceInCents)),
            ),
            columns: [
              BackofficeListColumn<_PayrollEntry>(
                label: 'Empleado',
                width: 280,
                compare: (a, b) => a.employeeName.compareTo(b.employeeName),
                cell: (_, entry) => Text(entry.employeeName),
              ),
              BackofficeListColumn<_PayrollEntry>(
                label: 'Período',
                width: 245,
                compare: (a, b) => a.periodStart.compareTo(b.periodStart),
                cell: (_, entry) => Text(entry.periodLabel),
              ),
              BackofficeListColumn<_PayrollEntry>(
                label: 'Salario',
                width: 155,
                alignment: Alignment.centerRight,
                compare: (a, b) =>
                    a.baseSalaryInCents.compareTo(b.baseSalaryInCents),
                cell: (_, entry) => Text(_money(entry.baseSalaryInCents)),
              ),
              BackofficeListColumn<_PayrollEntry>(
                label: 'Consumos',
                width: 160,
                alignment: Alignment.centerRight,
                cell: (_, entry) => Text(_money(entry.consumptionInCents)),
              ),
              BackofficeListColumn<_PayrollEntry>(
                label: 'Pagado',
                width: 150,
                alignment: Alignment.centerRight,
                compare: (a, b) => a.paidInCents.compareTo(b.paidInCents),
                cell: (_, entry) => Text(_money(entry.paidInCents)),
              ),
              BackofficeListColumn<_PayrollEntry>(
                label: 'Por pagar',
                width: 175,
                alignment: Alignment.centerRight,
                compare: (a, b) => a.balanceInCents.compareTo(b.balanceInCents),
                cell: (_, entry) => Text(_money(entry.balanceInCents)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showBreakdown(BuildContext context, _PayrollEntry entry) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(entry.employeeName),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.periodLabel),
                const SizedBox(height: 8),
                const _PayrollSectionHeader('Nómina'),
                _PayrollRow(label: 'Salario', value: entry.baseSalaryInCents),
                _PayrollRow(
                  label: 'Horas extras',
                  value: entry.overtimeInCents,
                ),
                _PayrollRow(label: 'Consumo', value: entry.consumptionInCents),
                if (entry.rawMaterialConsumptionInCents > 0) ...[
                  _PayrollRow(
                    label: 'Consumo POS',
                    value: entry.posConsumptionInCents,
                  ),
                  _PayrollRow(
                    label: 'Materia prima',
                    value: entry.rawMaterialConsumptionInCents,
                  ),
                ],
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
                  label: 'Por pagar de nómina',
                  value: entry.balanceInCents,
                  strong: true,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
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
    final rawConsumptionByEmployee = <String, int>{};
    for (final consumption in rawConsumptions.where((item) {
      return item.payrollRunId == null &&
          !_isBeforeDate(item.consumedAt, period.start) &&
          !_isAfterDate(item.consumedAt, period.end);
    })) {
      rawConsumptionByEmployee.update(
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
      final rawConsumption = rawConsumptionByEmployee[employee.id] ?? 0;
      final totalConsumption = consumption + rawConsumption;
      final overtime = overtimeByEmployee[employee.id] ?? 0;
      final advance = advancesByEmployee[employee.id] ?? 0;
      final balance = employee.baseSalaryInCents + overtime - totalConsumption;
      if (balance <= 0) continue;
      entries.add(
        _PayrollEntry(
          employeeId: employee.id,
          employeeName: employee.fullName,
          periodStart: period.start,
          periodEnd: period.end,
          periodLabel: period.label,
          baseSalaryInCents: employee.baseSalaryInCents,
          consumptionInCents: totalConsumption,
          posConsumptionInCents: consumption,
          rawMaterialConsumptionInCents: rawConsumption,
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
