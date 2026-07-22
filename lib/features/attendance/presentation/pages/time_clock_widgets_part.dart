part of 'time_clock_page.dart';

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
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
