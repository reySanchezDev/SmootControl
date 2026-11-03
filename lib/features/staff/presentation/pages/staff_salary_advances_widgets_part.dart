part of 'staff_admin_pages.dart';

class _SalaryAdvanceRangeFilter extends StatelessWidget {
  const _SalaryAdvanceRangeFilter({
    required this.from,
    required this.onChanged,
    required this.onMonth,
    required this.onReload,
    required this.to,
  });

  final DateTime from;
  final ValueChanged<DateTimeRange> onChanged;
  final VoidCallback onMonth;
  final VoidCallback onReload;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickRange(context),
                icon: const Icon(Icons.date_range_outlined),
                label: Text('${_dateOnly(from)} - ${_dateOnly(to)}'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: onMonth,
              icon: const Icon(Icons.calendar_month_outlined),
              tooltip: 'Mes actual',
            ),
            const SizedBox(width: 8),
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

class _SalaryAdvanceList extends StatelessWidget {
  const _SalaryAdvanceList({
    required this.advances,
    required this.employees,
    required this.hasFilter,
    required this.onDelete,
  });

  final List<SalaryAdvance> advances;
  final List<Employee> employees;
  final bool hasFilter;
  final ValueChanged<SalaryAdvance> onDelete;

  @override
  Widget build(BuildContext context) {
    final employeeById = {
      for (final employee in employees) employee.id: employee,
    };
    String name(SalaryAdvance advance) =>
        employeeById[advance.employeeId]?.fullName ?? 'Empleado';
    int balance(SalaryAdvance advance) =>
        advance.balanceInCents ?? advance.amountInCents;

    return BackofficeCollectionView<SalaryAdvance>(
      items: advances,
      rowKey: (advance) => advance.id,
      rowLabel: name,
      selectionActions: [
        BackofficeSelectionAction<SalaryAdvance>(
          label: 'Eliminar',
          icon: Icons.delete_outline,
          destructive: true,
          onPressed: onDelete,
        ),
      ],
      searchLabel: 'Buscar adelanto',
      searchTextFor: (advance) => [
        name(advance),
        employeeById[advance.employeeId]?.code ?? '',
        advance.affectsCash ? 'Afecta caja' : 'Cuenta externa',
        _dateOnly(advance.deliveredAt),
        _salaryAdvanceStatusLabel(advance.status),
        _money(advance.amountInCents),
        _money(advance.amountInCents - balance(advance)),
        _money(balance(advance)),
        advance.note ?? '',
      ].join(' '),
      emptyTitle: hasFilter ? 'Sin resultados' : 'Sin adelantos activos',
      emptyMessage: hasFilter
          ? 'No hay adelantos pendientes o parciales en este filtro.'
          : 'Los adelantos pendientes aparecerán aquí.',
      compactBuilder: (_, advance) => ListTile(
        leading: Icon(
          advance.affectsCash
              ? Icons.point_of_sale_outlined
              : Icons.account_balance_outlined,
        ),
        title: Text(name(advance)),
        subtitle: Text(
          '${_dateOnly(advance.deliveredAt)} · '
          '${_salaryAdvanceStatusLabel(advance.status)}',
        ),
        trailing: Text(_money(balance(advance))),
      ),
      columns: [
        BackofficeListColumn<SalaryAdvance>(
          label: 'Empleado',
          width: 240,
          compare: (a, b) => name(a).compareTo(name(b)),
          cell: (_, advance) => Text(name(advance)),
        ),
        BackofficeListColumn<SalaryAdvance>(
          label: 'Entrega',
          width: 155,
          compare: (a, b) => a.deliveredAt.compareTo(b.deliveredAt),
          cell: (_, advance) => Text(_dateOnly(advance.deliveredAt)),
        ),
        BackofficeListColumn<SalaryAdvance>(
          label: 'Estado',
          width: 135,
          compare: (a, b) => a.status.compareTo(b.status),
          cell: (_, advance) =>
              Text(_salaryAdvanceStatusLabel(advance.status)),
        ),
        BackofficeListColumn<SalaryAdvance>(
          label: 'Adelanto',
          width: 160,
          alignment: Alignment.centerRight,
          compare: (a, b) => a.amountInCents.compareTo(b.amountInCents),
          cell: (_, advance) => Text(_money(advance.amountInCents)),
        ),
        BackofficeListColumn<SalaryAdvance>(
          label: 'Abonado',
          width: 160,
          alignment: Alignment.centerRight,
          cell: (_, advance) =>
              Text(_money(advance.amountInCents - balance(advance))),
        ),
        BackofficeListColumn<SalaryAdvance>(
          label: 'Saldo',
          width: 160,
          alignment: Alignment.centerRight,
          compare: (a, b) => balance(a).compareTo(balance(b)),
          cell: (_, advance) => Text(_money(balance(advance))),
        ),
      ],
    );
  }
}

String _salaryAdvanceStatusLabel(String status) {
  return switch (status) {
    'pending' => 'Pendiente',
    'partially_paid' => 'Parcial',
    'paid' => 'Pagado',
    _ => status,
  };
}
