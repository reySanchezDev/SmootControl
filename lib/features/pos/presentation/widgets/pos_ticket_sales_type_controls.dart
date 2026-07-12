part of 'pos_ticket_panel.dart';

String _mobileSalesTypeLabel(SalesType type) {
  final normalized = type.code.trim().toLowerCase();
  if (normalized == 'dine_in' || normalized == 'eat_here') return 'AquÃ­';
  if (normalized == 'to_go' || normalized == 'takeout') return 'GO';

  final name = type.name.trim().toLowerCase();
  if (name == 'comer aqui' || name == 'aqui') return 'AquÃ­';
  if (name == 'para llevar' || name == 'llevar') return 'GO';
  return type.name;
}

class _SalesTypeSelector extends StatelessWidget {
  const _SalesTypeSelector({
    required this.salesTypes,
    required this.selectedSalesTypeId,
    required this.alignment,
  });

  final List<SalesType> salesTypes;
  final String? selectedSalesTypeId;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final activeTypes = salesTypes.where((type) => type.isActive).toList();
    if (activeTypes.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final type in activeTypes)
          _SalesTypeChip(
            label: type.name,
            selected: type.id == selectedSalesTypeId,
            onPressed: () {
              context.read<PosBloc>().add(PosSalesTypeSelected(type.id));
            },
          ),
      ],
    );
  }
}

class _SalesTypeChip extends StatelessWidget {
  const _SalesTypeChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.compact = false,
  });

  final bool compact;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: compact ? 54 : 72,
        minHeight: 38,
        maxWidth: compact ? 80 : 180,
      ),
      child: Material(
        color: selected ? AppPalette.primaryDark : colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: colorScheme.onPrimary.withValues(alpha: selected ? .35 : .2),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: selected ? null : onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 13,
              vertical: 9,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
