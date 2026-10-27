part of 'vacation_requests_page.dart';

class _VacationFilters extends StatelessWidget {
  const _VacationFilters({
    required this.from,
    required this.to,
    required this.employees,
    required this.onFrom,
    required this.onTo,
    required this.onReload,
    required this.onEmployee,
    required this.onStatus,
    this.employeeId,
    this.status,
  });

  final DateTime from;
  final DateTime to;
  final List<Employee> employees;
  final String? employeeId;
  final String? status;
  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback onReload;
  final ValueChanged<String?> onEmployee;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ActionChip(
              avatar: const Icon(Icons.calendar_month_outlined),
              label: Text('Desde ${_fmt(from)}'),
              onPressed: onFrom,
            ),
            ActionChip(
              avatar: const Icon(Icons.calendar_month_outlined),
              label: Text('Hasta ${_fmt(to)}'),
              onPressed: onTo,
            ),
            DropdownButton<String?>(
              value: employeeId,
              hint: const Text('Empleado'),
              items: [
                const DropdownMenuItem(child: Text('Todos')),
                for (final employee in employees)
                  DropdownMenuItem(
                    value: employee.id,
                    child: Text(employee.fullName),
                  ),
              ],
              onChanged: onEmployee,
            ),
            DropdownButton<String?>(
              value: status,
              hint: const Text('Estado'),
              items: const [
                DropdownMenuItem(child: Text('Todos')),
                DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
                DropdownMenuItem(value: 'approved', child: Text('Aprobadas')),
                DropdownMenuItem(value: 'rejected', child: Text('Rechazadas')),
              ],
              onChanged: onStatus,
            ),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Recargar'),
              onPressed: onReload,
            ),
          ],
        ),
      ),
    );
  }
}

class _VacationCard extends StatelessWidget {
  const _VacationCard({required this.item, required this.onAction});

  final VacationRequest item;
  final Future<void> Function(VacationRequest item, String action) onAction;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (item.status) {
      'pending' => 'Pendiente',
      'approved' => 'Aprobada',
      'rejected' => 'Rechazada',
      _ => item.status,
    };
    final typeText = item.requestType == 'taken' ? 'Tomado' : 'Programado';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.beach_access_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText(
                    '${item.employeeName} | $statusText',
                    variant: AppTextVariant.titleMedium,
                  ),
                ),
                if (item.isPending)
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: () => unawaited(onAction(item, 'approved')),
                  ),
                if (item.isPending)
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined),
                    onPressed: () => unawaited(onAction(item, 'rejected')),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => unawaited(onAction(item, 'delete')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Row(
              label: 'Periodo',
              value: '${_fmt(item.startDate)} - ${_fmt(item.endDate)}',
            ),
            _Row(label: 'Dias', value: item.requestedDays.toStringAsFixed(2)),
            _Row(label: 'Tipo', value: typeText),
            _Row(
              label: 'Origen',
              value: item.source == 'admin' ? 'Admin' : 'Marcador',
            ),
            if (item.note != null) _Row(label: 'Nota', value: item.note!),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AppText(label)),
        Flexible(child: AppText(value, textAlign: TextAlign.end)),
      ],
    );
  }
}

String _fmt(DateTime date) =>
    '${_two(date.day)}/${_two(date.month)}/${date.year}';

String _two(int value) => value.toString().padLeft(2, '0');
