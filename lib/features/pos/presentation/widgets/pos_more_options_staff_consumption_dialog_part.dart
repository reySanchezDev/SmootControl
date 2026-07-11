part of 'pos_more_options_panel.dart';

class _EmployeePickerDialog extends StatelessWidget {
  const _EmployeePickerDialog({required this.employees});

  final List<Employee> employees;

  @override
  Widget build(BuildContext context) {
    return _StaffConsumptionDialog(employees: employees);
  }
}

class _StaffConsumptionDialog extends StatefulWidget {
  const _StaffConsumptionDialog({required this.employees});

  final List<Employee> employees;

  @override
  State<_StaffConsumptionDialog> createState() =>
      _StaffConsumptionDialogState();
}

class _StaffConsumptionDialogState extends State<_StaffConsumptionDialog> {
  String? _employeeId;
  DateTime _deliveredAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _employeeId = widget.employees.isEmpty ? null : widget.employees.first.id;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveTouchDialogFrame(
      maxWidth: 420,
      title: const AppText(
        'Consumo personal',
        variant: AppTextVariant.titleMedium,
      ),
      content: widget.employees.isEmpty
          ? const AppText('No hay empleados activos sincronizados.')
          : Column(
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha de entrega'),
                  subtitle: Text(_shortDate(_deliveredAt)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _pickDeliveredAt,
                ),
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

  void _submit() {
    Employee? employee;
    for (final item in widget.employees) {
      if (item.id == _employeeId) {
        employee = item;
        break;
      }
    }
    if (employee == null) return;
    Navigator.of(context).pop((employee: employee, deliveredAt: _deliveredAt));
  }
}
