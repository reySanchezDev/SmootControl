part of 'staff_admin_pages.dart';

class _SalaryAdvanceDialog extends StatefulWidget {
  const _SalaryAdvanceDialog({required this.employees});

  final List<Employee> employees;

  @override
  State<_SalaryAdvanceDialog> createState() => _SalaryAdvanceDialogState();
}

class _SalaryAdvanceDialogState extends State<_SalaryAdvanceDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _employeeId;
  DateTime _deliveredAt = DateTime.now();
  bool _affectsCash = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _employeeId = widget.employees.isEmpty ? null : widget.employees.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar adelanto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _employeeId,
            decoration: const InputDecoration(labelText: 'Empleado'),
            items: [
              for (final employee in widget.employees)
                DropdownMenuItem(
                  value: employee.id,
                  child: Text(employee.fullName),
                ),
            ],
            onChanged: (value) => setState(() => _employeeId = value),
          ),
          TextField(
            controller: _amount,
            decoration: const InputDecoration(labelText: 'Monto'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Nota'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha de entrega'),
            subtitle: Text(_dateOnly(_deliveredAt)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _pickDeliveredAt,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _affectsCash,
            title: const Text('Afecta caja'),
            subtitle: const Text(
              'Activalo solo si el dinero sale de caja POS.',
            ),
            onChanged: (value) => setState(() => _affectsCash = value),
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

  void _submit() {
    final employeeId = _employeeId;
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    final userId = serviceLocator<CurrentRemoteSessionService>().userId;
    if (employeeId == null || amount == null || amount <= 0 || userId == null) {
      setState(() => _error = 'Verifica empleado, monto y sesion admin.');
      return;
    }
    Navigator.of(context).pop(
      SalaryAdvance(
        id: const Uuid().v4(),
        employeeId: employeeId,
        amountInCents: (amount * 100).round(),
        affectsCash: _affectsCash,
        note: _optional(_note.text),
        createdBy: userId,
        createdAt: DateTime.now(),
        deliveredAt: _deliveredAt,
      ),
    );
  }

  Future<void> _pickDeliveredAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _deliveredAt = picked);
  }
}
