part of 'attendance_admin_page.dart';

class _AttendanceFilters extends StatelessWidget {
  const _AttendanceFilters({
    required this.from,
    required this.onFrom,
    required this.onReload,
    required this.onStatus,
    required this.status,
    required this.to,
    required this.onTo,
  });

  final DateTime from;
  final VoidCallback onFrom;
  final VoidCallback onReload;
  final ValueChanged<String?> onStatus;
  final String? status;
  final DateTime to;
  final VoidCallback onTo;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 8,
      spacing: 8,
      children: [
        _DateChip(label: 'Desde ${_fmt(from)}', onTap: onFrom),
        _DateChip(label: 'Hasta ${_fmt(to)}', onTap: onTo),
        DropdownButton<String?>(
          value: status,
          hint: const Text('Estado'),
          items: const [
            DropdownMenuItem(child: Text('Todos')),
            DropdownMenuItem(value: 'open', child: Text('Abiertas')),
            DropdownMenuItem(value: 'closed', child: Text('Cerradas')),
          ],
          onChanged: onStatus,
        ),
        FilledButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Recargar'),
          onPressed: onReload,
        ),
      ],
    );
  }
}

class _AttendanceEntryCard extends StatelessWidget {
  const _AttendanceEntryCard({
    required this.entry,
    required this.onEdit,
    required this.onVoid,
  });

  final AttendanceEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onVoid;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_outlined, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    '${entry.employeeName} | ${_fmt(entry.workDate)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    variant: AppTextVariant.titleMedium,
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                  ),
                if (onVoid != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onVoid,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'Entrada', value: _time(entry.clockInAt)),
            _InfoRow(label: 'Salida', value: _time(entry.clockOutAt)),
            _InfoRow(label: 'Estado', value: _status(entry.status)),
            if (entry.deviceName != null)
              _InfoRow(label: 'Dispositivo', value: entry.deviceName!),
          ],
        ),
      ),
    );
  }
}

class _AttendanceEditorDialog extends StatefulWidget {
  const _AttendanceEditorDialog({required this.employees, this.entry});

  final List<Employee> employees;
  final AttendanceEntry? entry;

  @override
  State<_AttendanceEditorDialog> createState() =>
      _AttendanceEditorDialogState();
}

class _AttendanceEditorDialogState extends State<_AttendanceEditorDialog> {
  late Employee _employee;
  late TimeOfDay _inTime;
  TimeOfDay? _outTime;
  late DateTime _workDate;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _employee = widget.employees.firstWhere(
      (item) => item.id == entry?.employeeId,
      orElse: () => widget.employees.first,
    );
    final now = DateTime.now();
    _workDate = entry?.workDate ?? DateTime(now.year, now.month, now.day);
    _inTime = TimeOfDay.fromDateTime(entry?.clockInAt ?? now);
    _outTime = entry?.clockOutAt == null
        ? null
        : TimeOfDay.fromDateTime(entry!.clockOutAt!);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? 'Crear marcada' : 'Editar marcada'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Employee>(
              initialValue: _employee,
              decoration: const InputDecoration(labelText: 'Empleado'),
              items: [
                for (final item in widget.employees)
                  DropdownMenuItem(value: item, child: Text(item.fullName)),
              ],
              onChanged: (value) => setState(() => _employee = value!),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Fecha ${_fmt(_workDate)}'),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Entrada ${_inTime.format(context)}'),
              trailing: const Icon(Icons.login),
              onTap: () => _pickTime(isIn: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _outTime == null
                    ? 'Salida pendiente'
                    : 'Salida ${_outTime!.format(context)}',
              ),
              trailing: const Icon(Icons.logout),
              onTap: () => _pickTime(isIn: false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      initialDate: _workDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _workDate = picked);
  }

  Future<void> _pickTime({required bool isIn}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isIn ? _inTime : _outTime ?? _inTime,
    );
    if (picked == null) return;
    setState(() {
      if (isIn) {
        _inTime = picked;
      } else {
        _outTime = picked;
      }
    });
  }

  void _save() {
    final entry = widget.entry;
    final clockIn = _dateTime(_workDate, _inTime);
    final clockOut = _outTime == null ? null : _dateTime(_workDate, _outTime!);
    Navigator.of(context).pop(
      AttendanceEntry(
        id: entry?.id ?? '',
        employeeId: _employee.id,
        employeeName: _employee.fullName,
        workDate: _workDate,
        clockInAt: clockIn,
        clockOutAt: clockOut,
        status: clockOut == null ? 'open' : 'closed',
        source: 'admin',
        verificationMethod: 'admin',
        createdAt: entry?.createdAt ?? DateTime.now(),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.calendar_month_outlined),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AppText(label)),
        AppText(value, variant: AppTextVariant.label),
      ],
    );
  }
}

DateTime _dateTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String _fmt(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

String _time(DateTime? value) {
  if (value == null) return 'Pendiente';
  String two(int input) => input.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}';
}

String _status(String status) {
  return switch (status) {
    'open' => 'Abierta',
    'closed' => 'Cerrada',
    'voided' => 'Anulada',
    _ => status,
  };
}
