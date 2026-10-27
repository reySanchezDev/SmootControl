part of 'vacation_requests_page.dart';

class _VacationFormDialog extends StatefulWidget {
  const _VacationFormDialog({required this.employees});

  final List<Employee> employees;

  @override
  State<_VacationFormDialog> createState() => _VacationFormDialogState();
}

class _VacationFormDialogState extends State<_VacationFormDialog> {
  final _uuid = const Uuid();
  final _note = TextEditingController();
  late String _employeeId = widget.employees.first.id;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  String _type = 'planned';
  bool _approved = true;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar vacaciones'),
      content: SingleChildScrollView(
        child: Column(
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
              onChanged: (value) => setState(() => _employeeId = value!),
            ),
            Row(
              children: [
                Expanded(
                  child: ActionChip(
                    label: Text('Desde ${_fmt(_from)}'),
                    onPressed: () => _pick(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ActionChip(
                    label: Text('Hasta ${_fmt(_to)}'),
                    onPressed: () => _pick(false),
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'planned', child: Text('Programado')),
                DropdownMenuItem(value: 'taken', child: Text('Ya tomado')),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            CheckboxListTile(
              value: _approved,
              title: const Text('Crear aprobado'),
              onChanged: (value) => setState(() => _approved = value ?? true),
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Nota'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _pick(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      initialDate: isFrom ? _from : _to,
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked.isBefore(_from) ? _from : picked;
      }
    });
  }

  void _submit() {
    final employee = widget.employees.firstWhere((item) {
      return item.id == _employeeId;
    });
    final days =
        _to.difference(DateTime(_from.year, _from.month, _from.day)).inDays + 1;
    Navigator.pop(
      context,
      VacationRequest(
        id: _uuid.v4(),
        employeeId: employee.id,
        employeeName: employee.fullName,
        startDate: DateTime(_from.year, _from.month, _from.day),
        endDate: DateTime(_to.year, _to.month, _to.day),
        requestedDays: days.toDouble(),
        requestType: _type,
        status: _approved ? 'approved' : 'pending',
        source: 'admin',
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        createdAt: DateTime.now(),
      ),
    );
  }
}
