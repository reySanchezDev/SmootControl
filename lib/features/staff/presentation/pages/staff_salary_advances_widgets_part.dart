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
    if (advances.isEmpty) {
      return AppEmptyState(
        icon: Icons.payments_outlined,
        title: 'Sin adelantos activos',
        message: hasFilter
            ? 'No hay adelantos pendientes o parciales en este filtro.'
            : 'Los adelantos pendientes apareceran aqui.',
      );
    }
    final employeeById = {
      for (final employee in employees) employee.id: employee,
    };
    return ListView.separated(
      itemCount: advances.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final advance = advances[index];
        final employee = employeeById[advance.employeeId];
        final balance = advance.balanceInCents ?? advance.amountInCents;
        final paid = advance.amountInCents - balance;
        return ListTile(
          leading: Icon(
            advance.affectsCash
                ? Icons.point_of_sale_outlined
                : Icons.account_balance_outlined,
          ),
          title: Text(employee?.fullName ?? 'Empleado'),
          subtitle: Text(
            [
              'Entrega: ${_dateOnly(advance.deliveredAt)}',
              _salaryAdvanceStatusLabel(advance.status),
              'Adelanto: ${_money(advance.amountInCents)}',
              'Abonado: ${_money(paid)}',
              'Saldo: ${_money(balance)}',
            ].join(' - '),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_money(balance)),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete(advance),
              ),
            ],
          ),
        );
      },
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
