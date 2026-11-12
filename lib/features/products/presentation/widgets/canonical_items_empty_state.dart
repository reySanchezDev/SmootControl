import 'package:flutter/material.dart';

/// Reusable guided empty state for canonical administrative catalogs.
class CanonicalItemsEmptyState extends StatelessWidget {
  const CanonicalItemsEmptyState({
    required this.noRecords,
    required this.busy,
    required this.onCreate,
    required this.onClearFilters,
    super.key,
  });

  final bool noRecords;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              noRecords
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              noRecords
                  ? 'Todavía no hay artículos'
                  : 'No encontramos coincidencias',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              noRecords
                  ? 'Crea el primer artículo para organizar ventas, compras y consumo.'
                  : 'Probá con otro nombre, código o tipo de artículo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (noRecords)
              FilledButton.icon(
                onPressed: busy ? null : onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Crear artículo'),
              )
            else
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Quitar filtros'),
              ),
          ],
        ),
      ),
    ),
  );
}
