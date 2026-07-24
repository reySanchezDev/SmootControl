part of 'staff_admin_pages.dart';

class _WorkShiftSection extends StatelessWidget {
  const _WorkShiftSection({required this.shifts, required this.onChanged});

  final List<EmployeeWorkShift> shifts;
  final ValueChanged<EmployeeWorkShift> onChanged;

  @override
  Widget build(BuildContext context) {
    final defaults = _defaultShifts(shifts);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Turnos de asistencia'),
            const SizedBox(height: 8),
            for (final shift in defaults) ...[
              _WorkShiftTile(shift: shift, onChanged: onChanged),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  List<EmployeeWorkShift> _defaultShifts(List<EmployeeWorkShift> current) {
    EmployeeWorkShift byName(String name, String start, String end) {
      return current.firstWhere(
        (shift) => shift.name.toUpperCase() == name,
        orElse: () => EmployeeWorkShift(
          id: '',
          name: name,
          startTime: start,
          endTime: end,
        ),
      );
    }

    return [
      byName('TURNO A', '08:00', '17:00'),
      byName('TURNO B', '15:00', '22:00'),
    ];
  }
}

class _WorkShiftTile extends StatefulWidget {
  const _WorkShiftTile({required this.shift, required this.onChanged});

  final EmployeeWorkShift shift;
  final ValueChanged<EmployeeWorkShift> onChanged;

  @override
  State<_WorkShiftTile> createState() => _WorkShiftTileState();
}

class _WorkShiftTileState extends State<_WorkShiftTile> {
  late TimeOfDay _start = _parseTime(widget.shift.startTime);
  late TimeOfDay _end = _parseTime(widget.shift.endTime);

  @override
  void didUpdateWidget(covariant _WorkShiftTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shift != widget.shift) {
      _start = _parseTime(widget.shift.startTime);
      _end = _parseTime(widget.shift.endTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(widget.shift.name),
      subtitle: Text('${_fmtTime(_start)} - ${_fmtTime(_end)}'),
      trailing: FilledButton.icon(
        icon: const Icon(Icons.save_outlined),
        label: const Text('Guardar'),
        onPressed: _save,
      ),
      onTap: _edit,
    );
  }

  Future<void> _edit() async {
    final start = await showTimePicker(context: context, initialTime: _start);
    if (start == null || !mounted) return;
    final end = await showTimePicker(context: context, initialTime: _end);
    if (end == null) return;
    setState(() {
      _start = start;
      _end = end;
    });
  }

  void _save() {
    widget.onChanged(
      EmployeeWorkShift(
        id: widget.shift.id,
        name: widget.shift.name,
        startTime: _fmtTime(_start),
        endTime: _fmtTime(_end),
        isActive: widget.shift.isActive,
      ),
    );
  }
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.first) ?? 0,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

String _fmtTime(TimeOfDay value) {
  String two(int input) => input.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}';
}
