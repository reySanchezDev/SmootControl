part of 'pos_more_options_panel.dart';

class _SalaryAdvancePosDialog extends StatefulWidget {
  const _SalaryAdvancePosDialog({
    required this.affectsCash,
    required this.employees,
    this.cashRegisterSessionId,
  });

  final bool affectsCash;
  final String? cashRegisterSessionId;
  final List<Employee> employees;

  @override
  State<_SalaryAdvancePosDialog> createState() =>
      _SalaryAdvancePosDialogState();
}

class _SalaryAdvancePosDialogState extends State<_SalaryAdvancePosDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _employeeId;
  DateTime _deliveredAt = DateTime.now();
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
    return ResponsiveTouchDialogFrame(
      maxWidth: 420,
      title: const AppText(
        'Adelanto salario',
        variant: AppTextVariant.titleMedium,
      ),
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
            subtitle: Text(_shortDate(_deliveredAt)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _pickDeliveredAt,
          ),
          const SizedBox(height: 10),
          AppText(
            widget.affectsCash
                ? 'Este adelanto afectara caja.'
                : 'Este adelanto saldra de cuenta externa.',
            textAlign: TextAlign.center,
            variant: AppTextVariant.label,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            AppText(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
              variant: AppTextVariant.label,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    final employeeId = _employeeId;
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    final createdBy = serviceLocator<CurrentOperatorService>().userId;
    if (employeeId == null || amount == null || amount <= 0) {
      setState(() => _error = 'Verifica empleado y monto.');
      return;
    }
    Navigator.of(context).pop(
      SalaryAdvance(
        id: const Uuid().v4(),
        employeeId: employeeId,
        cashRegisterSessionId: widget.cashRegisterSessionId,
        amountInCents: (amount * 100).round(),
        affectsCash: widget.affectsCash,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        createdBy: createdBy,
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
