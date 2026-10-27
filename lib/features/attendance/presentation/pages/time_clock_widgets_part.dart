part of 'time_clock_page.dart';

enum _ClockAction { mark, vacation }

class _EmployeeClockGrid extends StatelessWidget {
  const _EmployeeClockGrid({
    required this.employees,
    required this.onSelected,
  });

  final List<Employee> employees;
  final ValueChanged<Employee> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 148,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        return _EmployeeClockCard(
          employee: employees[index],
          index: index,
          onTap: () => onSelected(employees[index]),
        );
      },
    );
  }
}

class _EmployeeClockCard extends StatelessWidget {
  const _EmployeeClockCard({
    required this.employee,
    required this.index,
    required this.onTap,
  });

  final Employee employee;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = _employeeColor(colorScheme, index);
    final foreground = colorScheme.onSurface;
    return Material(
      borderRadius: BorderRadius.circular(8),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: cardColor.withValues(alpha: 0.38)),
            borderRadius: BorderRadius.circular(8),
            color: Color.lerp(
              colorScheme.surfaceContainerHighest,
              cardColor,
              0.22,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                color: colorScheme.shadow.withValues(alpha: 0.08),
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    color: cardColor,
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: AppText(
                    employee.fullName,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                    textAlign: TextAlign.center,
                    variant: AppTextVariant.titleLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _employeeColor(ColorScheme colorScheme, int index) {
    final colors = [
      colorScheme.primary,
      colorScheme.tertiary,
      colorScheme.secondary,
      colorScheme.error,
      Color.lerp(colorScheme.primary, colorScheme.secondary, 0.55)!,
      Color.lerp(colorScheme.tertiary, colorScheme.primary, 0.45)!,
    ];
    return colors[index % colors.length];
  }
}

class _ClockConfirmDialog extends StatelessWidget {
  const _ClockConfirmDialog({required this.employee, this.openEntry});

  final Employee employee;
  final AttendanceEntry? openEntry;

  @override
  Widget build(BuildContext context) {
    final isExit = openEntry != null;
    return AlertDialog(
      title: Text(employee.fullName),
      content: AppText(
        isExit ? 'Confirmar salida laboral.' : 'Confirmar entrada laboral.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          icon: Icon(isExit ? Icons.logout : Icons.login),
          label: Text(isExit ? 'Marcar salida' : 'Marcar entrada'),
          onPressed: () => Navigator.of(context).pop(_ClockAction.mark),
        ),
        TextButton.icon(
          icon: const Icon(Icons.beach_access_outlined),
          label: const Text('Vacaciones'),
          onPressed: () => Navigator.of(context).pop(_ClockAction.vacation),
        ),
      ],
    );
  }
}

class _VacationRange {
  const _VacationRange({required this.from, required this.to, this.note});

  final DateTime from;
  final DateTime to;
  final String? note;
}

class _VacationRequestDialog extends StatefulWidget {
  const _VacationRequestDialog({required this.employee});

  final Employee employee;

  @override
  State<_VacationRequestDialog> createState() => _VacationRequestDialogState();
}

class _VacationRequestDialogState extends State<_VacationRequestDialog> {
  final _note = TextEditingController();
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Vacaciones: ${widget.employee.fullName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ActionChip(
            avatar: const Icon(Icons.calendar_month_outlined),
            label: Text('Desde ${_fmt(_from)}'),
            onPressed: () => _pick(isFrom: true),
          ),
          const SizedBox(height: 8),
          ActionChip(
            avatar: const Icon(Icons.calendar_month_outlined),
            label: Text('Hasta ${_fmt(_to)}'),
            onPressed: () => _pick(isFrom: false),
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Nota'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.send_outlined),
          label: const Text('Solicitar'),
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _pick({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
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
    Navigator.of(context).pop(
      _VacationRange(
        from: DateTime(_from.year, _from.month, _from.day),
        to: DateTime(_to.year, _to.month, _to.day),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }
}

String _fmt(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
