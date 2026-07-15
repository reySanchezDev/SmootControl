part of 'staff_admin_pages.dart';

class _OvertimeDialog extends StatefulWidget {
  const _OvertimeDialog({required this.employees, this.entry});

  final List<Employee> employees;
  final EmployeeOvertimeEntry? entry;

  @override
  State<_OvertimeDialog> createState() => _OvertimeDialogState();
}

class _OvertimeDialogState extends State<_OvertimeDialog> {
  late final _hours = TextEditingController(
    text: widget.entry?.hours.toString() ?? '',
  );
  late final _note = TextEditingController(text: widget.entry?.note ?? '');
  late String? _employeeId =
      widget.entry?.employeeId ??
      (widget.employees.isEmpty ? null : widget.employees.first.id);
  late DateTime _workedDate = widget.entry?.workedDate ?? DateTime.now();
  String? _error;

  @override
  void dispose() {
    _hours.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.entry == null ? 'Registrar hora extra' : 'Editar hora extra',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _employeeSelector(),
          TextField(
            controller: _hours,
            decoration: const InputDecoration(labelText: 'Horas extras'),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
            ],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Observacion'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha'),
            subtitle: Text(_dateOnly(_workedDate)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _pickDate,
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }

  Widget _employeeSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _employeeId,
      decoration: const InputDecoration(labelText: 'Empleado'),
      items: [
        for (final employee in widget.employees)
          DropdownMenuItem(value: employee.id, child: Text(employee.fullName)),
      ],
      onChanged: (value) => setState(() => _employeeId = value),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _workedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() => _workedDate = selected);
  }

  void _submit() {
    final employeeId = _employeeId;
    final hours = double.tryParse(_hours.text.trim().replaceAll(',', '.'));
    if (employeeId == null || hours == null || hours <= 0) {
      setState(() => _error = 'Verifica empleado, fecha y horas extras.');
      return;
    }
    Navigator.of(context).pop(
      EmployeeOvertimeEntry(
        id: widget.entry?.id ?? const Uuid().v4(),
        employeeId: employeeId,
        employeeName: widget.entry?.employeeName ?? '',
        workedDate: _workedDate,
        hours: hours,
        hourRateInCents: widget.entry?.hourRateInCents ?? 0,
        totalInCents: widget.entry?.totalInCents ?? 0,
        note: _optional(_note.text),
        status: widget.entry?.status ?? 'pending',
        createdAt: widget.entry?.createdAt ?? DateTime.now(),
      ),
    );
  }
}
