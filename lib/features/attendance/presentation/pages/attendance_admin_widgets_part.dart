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
    return Align(
      alignment: Alignment.centerLeft,
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
              initialValue: status,
              decoration: const InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Todos')),
                DropdownMenuItem(value: 'open', child: Text('Abiertas')),
                DropdownMenuItem(value: 'closed', child: Text('Cerradas')),
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
    );
  }

}

class _AttendanceEntryCard extends StatelessWidget {
  const _AttendanceEntryCard({
    required this.entry,
  });

  final AttendanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final worked = _workedHours(entry.clockInAt, entry.clockOutAt);
    final scheduled = _scheduledHours(entry);
    final overtime = worked == null || scheduled == null
        ? null
        : (worked - scheduled).clamp(0, double.infinity).toDouble();
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

              ],
            ),
            const SizedBox(height: 8),
            if (entry.workShiftName != null)
              _InfoRow(
                label: 'Turno',
                value:
                    '${entry.workShiftName} '
                    '${entry.workShiftStartTime ?? ''}-'
                    '${entry.workShiftEndTime ?? ''}',
              ),
            _InfoRow(label: 'Entrada', value: _time(entry.clockInAt)),
            _InfoRow(label: 'Salida', value: _time(entry.clockOutAt)),
            if (worked != null)
              _InfoRow(label: 'Horas laboradas', value: _hours(worked)),
            if (overtime != null)
              _InfoRow(label: 'Horas extra estimadas', value: _hours(overtime)),
            if (entry.overtimeHours != null)
              _InfoRow(
                label: 'Horas extra en bandeja',
                value:
                    '${_hours(entry.overtimeHours!)} '
                    '(${_status(entry.overtimeStatus ?? 'pending')})',
              ),
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
              trailing: const Icon(Icons.login_rounded, size: 24),
              onTap: () => _pickTime(isIn: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _outTime == null
                    ? 'Salida pendiente'
                    : 'Salida ${_outTime!.format(context)}',
              ),
              trailing: Icon(
                _outTime == null
                    ? Icons.pending_actions_rounded
                    : Icons.logout_rounded,
                size: 24,
              ),
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
    'pending' => 'Pendiente',
    'approved' => 'Aprobada',
    'rejected' => 'Rechazada',
    _ => status,
  };
}

double? _workedHours(DateTime? input, DateTime? output) {
  if (input == null || output == null) return null;
  return output.difference(input).inMinutes / 60;
}

double? _scheduledHours(AttendanceEntry entry) {
  final start = _timeOfDay(entry.workShiftStartTime);
  final end = _timeOfDay(entry.workShiftEndTime);
  if (start == null || end == null) return null;
  final startDate = _dateTime(entry.workDate, start);
  var endDate = _dateTime(entry.workDate, end);
  if (!endDate.isAfter(startDate)) {
    endDate = endDate.add(const Duration(days: 1));
  }
  return endDate.difference(startDate).inMinutes / 60;
}

TimeOfDay? _timeOfDay(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _hours(double value) {
  return '${value.toStringAsFixed(2)} h';
}
