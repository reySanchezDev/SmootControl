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
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: BackofficeFormStandards.filterGap,
          runSpacing: BackofficeFormStandards.filterGap,
          children: [
            SizedBox(
              width: BackofficeFormStandards.dateWidth,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('Desde ${_fmt(from)}'),
                onPressed: onFrom,
              ),
            ),
            SizedBox(
              width: BackofficeFormStandards.dateWidth,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('Hasta ${_fmt(to)}'),
                onPressed: onTo,
              ),
            ),
            SizedBox(
              width: BackofficeFormStandards.filterWidth,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: employeeId,
                decoration: const InputDecoration(
                  labelText: 'Empleado',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Todos')),
                  for (final employee in employees)
                    DropdownMenuItem(
                      value: employee.id,
                      child: Text(
                        employee.fullName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => onEmployee(
                  value == null || value.isEmpty ? null : value,
                ),
              ),
            ),
            SizedBox(
              width: BackofficeFormStandards.filterWidth,
              child: DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Todos')),
                  DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
                  DropdownMenuItem(value: 'approved', child: Text('Aprobadas')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rechazadas')),
                ],
                onChanged: (value) => onStatus(
                  value == null || value.isEmpty ? null : value,
                ),
              ),
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
  const _VacationCard({required this.item});

  final VacationRequest item;

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
