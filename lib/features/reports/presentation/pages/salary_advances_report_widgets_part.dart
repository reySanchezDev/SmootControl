part of 'salary_advances_report_page.dart';

class _SalaryAdvanceReportFilters extends StatelessWidget {
  const _SalaryAdvanceReportFilters({
    required this.from,
    required this.grouped,
    required this.onChanged,
    required this.onGroupedChanged,
    required this.onReload,
    required this.onStatusChanged,
    required this.status,
    required this.to,
  });

  final DateTime from;
  final bool grouped;
  final ValueChanged<DateTimeRange> onChanged;
  final ValueChanged<bool> onGroupedChanged;
  final VoidCallback onReload;
  final ValueChanged<String> onStatusChanged;
  final String status;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickRange(context),
              icon: const Icon(Icons.date_range_outlined),
              label: Text('${_dateOnly(from)} - ${_dateOnly(to)}'),
            ),
            DropdownButton<String>(
              value: status,
              items: const [
                DropdownMenuItem(value: 'paid', child: Text('Pagados')),
                DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
                DropdownMenuItem(
                  value: 'partially_paid',
                  child: Text('Parciales'),
                ),
                DropdownMenuItem(value: 'all', child: Text('Todos')),
              ],
              onChanged: (value) {
                if (value != null) onStatusChanged(value);
              },
            ),
            FilterChip(
              selected: grouped,
              label: const Text('Agrupar empleado'),
              onSelected: onGroupedChanged,
            ),
            IconButton.filled(
              onPressed: onReload,
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      initialDateRange: DateTimeRange(start: from, end: to),
      lastDate: DateTime(2100),
    );
    if (selected != null) onChanged(selected);
  }
}

class _SalaryAdvanceReportBody extends StatelessWidget {
  const _SalaryAdvanceReportBody({
    required this.advances,
    required this.employees,
    required this.grouped,
  });

  final List<SalaryAdvance> advances;
  final List<Employee> employees;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    if (advances.isEmpty) {
      return const AppEmptyState(
        icon: Icons.payments_outlined,
        title: 'Sin adelantos',
        message: 'No hay adelantos en este filtro.',
      );
    }
    final employeeById = {
      for (final employee in employees) employee.id: employee,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        _SalaryAdvanceTotals(advances: advances),
        const SizedBox(height: 8),
        if (grouped)
          ..._groupRows(employeeById).map(_GroupedAdvanceCard.new)
        else
          ...advances.map((advance) {
            return _AdvanceCard(
              advance: advance,
              employee: employeeById[advance.employeeId],
            );
          }),
      ],
    );
  }

  List<_GroupedAdvance> _groupRows(Map<String, Employee> employees) {
    final rows = <String, _GroupedAdvance>{};
    for (final advance in advances) {
      final balance = advance.balanceInCents ?? advance.amountInCents;
      rows.update(
        advance.employeeId,
        (row) {
          row.add(advance, balance);
          return row;
        },
        ifAbsent: () {
          return _GroupedAdvance(
            employeeName: employees[advance.employeeId]?.fullName ?? 'Empleado',
          )..add(advance, balance);
        },
      );
    }
    return rows.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }
}

class _SalaryAdvanceTotals extends StatelessWidget {
  const _SalaryAdvanceTotals({required this.advances});

  final List<SalaryAdvance> advances;

  @override
  Widget build(BuildContext context) {
    final total = advances.fold(0, (sum, item) => sum + item.amountInCents);
    final balance = advances.fold(
      0,
      (sum, item) => sum + (item.balanceInCents ?? item.amountInCents),
    );
    return Card(
      child: ListTile(
        title: const Text('Resumen'),
        subtitle: Text(
          'Entregado: ${MoneyFormatter.format(total)} - '
          'Abonado: ${MoneyFormatter.format(total - balance)}',
        ),
        trailing: Text('Saldo ${MoneyFormatter.format(balance)}'),
      ),
    );
  }
}

class _GroupedAdvance {
  _GroupedAdvance({required this.employeeName});

  final String employeeName;
  int balance = 0;
  int count = 0;
  int paid = 0;
  int totalAmount = 0;

  void add(SalaryAdvance advance, int currentBalance) {
    count++;
    totalAmount += advance.amountInCents;
    balance += currentBalance;
    paid += advance.amountInCents - currentBalance;
  }
}

class _GroupedAdvanceCard extends StatelessWidget {
  const _GroupedAdvanceCard(this.row);

  final _GroupedAdvance row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(row.employeeName),
        subtitle: Text(
          '${row.count} adelantos - Entregado: '
          '${MoneyFormatter.format(row.totalAmount)}',
        ),
        trailing: Text('Saldo ${MoneyFormatter.format(row.balance)}'),
      ),
    );
  }
}

class _AdvanceCard extends StatelessWidget {
  const _AdvanceCard({required this.advance, required this.employee});

  final SalaryAdvance advance;
  final Employee? employee;

  @override
  Widget build(BuildContext context) {
    final balance = advance.balanceInCents ?? advance.amountInCents;
    return Card(
      child: ListTile(
        title: Text(employee?.fullName ?? 'Empleado'),
        subtitle: Text(
          [
            'Entrega ${_dateOnly(advance.deliveredAt)}',
            _statusLabel(advance.status),
            'Adelanto ${MoneyFormatter.format(advance.amountInCents)}',
            'Abonado ${MoneyFormatter.format(advance.amountInCents - balance)}',
          ].join(' - '),
        ),
        trailing: Text(MoneyFormatter.format(balance)),
      ),
    );
  }
}

String _dateOnly(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

String _statusLabel(String status) {
  return switch (status) {
    'pending' => 'Pendiente',
    'partially_paid' => 'Parcial',
    'paid' => 'Pagado',
    _ => status,
  };
}
