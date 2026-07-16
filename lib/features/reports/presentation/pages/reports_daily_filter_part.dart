part of 'reports_page.dart';

class _DailySalesFilterCard extends StatelessWidget {
  const _DailySalesFilterCard({
    required this.from,
    required this.onMonthSelected,
    required this.onRangeChanged,
    required this.onReload,
    required this.onTodaySelected,
    required this.to,
    this.compactActions = false,
    this.monthLabel = 'Mes',
  });

  final bool compactActions;
  final DateTime from;
  final VoidCallback onMonthSelected;
  final ValueChanged<DateTimeRange> onRangeChanged;
  final VoidCallback onReload;
  final VoidCallback onTodaySelected;
  final DateTime to;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final rangeButton = _DateRangeFilterButton(
              from: from,
              onChanged: onRangeChanged,
              to: to,
            );
            final reloadButton = FilledButton.icon(
              onPressed: onReload,
              icon: const Icon(Icons.refresh),
              label: const Text('Recargar'),
            );
            final quickActions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.today_outlined, size: 18),
                  label: const Text('Hoy'),
                  onPressed: onTodaySelected,
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_view_month, size: 18),
                  label: Text(monthLabel),
                  onPressed: onMonthSelected,
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  rangeButton,
                  const SizedBox(height: 10),
                  if (compactActions)
                    _CompactDateActions(
                      monthLabel: monthLabel,
                      onMonthSelected: onMonthSelected,
                      onReload: onReload,
                      onTodaySelected: onTodaySelected,
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: quickActions),
                        const SizedBox(width: 10),
                        reloadButton,
                      ],
                    ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: rangeButton),
                const SizedBox(width: 10),
                quickActions,
                const SizedBox(width: 10),
                reloadButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompactDateActions extends StatelessWidget {
  const _CompactDateActions({
    required this.monthLabel,
    required this.onMonthSelected,
    required this.onReload,
    required this.onTodaySelected,
  });

  final String monthLabel;
  final VoidCallback onMonthSelected;
  final VoidCallback onReload;
  final VoidCallback onTodaySelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTodaySelected,
            icon: const Icon(Icons.today_outlined, size: 18),
            label: const Text('Hoy'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onMonthSelected,
            icon: const Icon(Icons.calendar_view_month, size: 18),
            label: Text(monthLabel),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onReload,
          icon: const Icon(Icons.refresh),
          tooltip: 'Recargar',
        ),
      ],
    );
  }
}

class _DateRangeFilterButton extends StatelessWidget {
  const _DateRangeFilterButton({
    required this.from,
    required this.onChanged,
    required this.to,
  });

  final DateTime from;
  final ValueChanged<DateTimeRange> onChanged;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final selected = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          initialDateRange: DateTimeRange(start: from, end: to),
          lastDate: DateTime(2100),
        );
        if (selected != null) onChanged(selected);
      },
      icon: const Icon(Icons.event_outlined),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(_rangeLabel(from, to)),
      ),
    );
  }
}
