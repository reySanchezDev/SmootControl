part of 'negative_inventory_report_page.dart';

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onReload,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: AppSearchField(
                controller: controller,
                label: 'Buscar materia prima o categoria',
                onChanged: onChanged,
                onClear: onClear,
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: onReload,
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
            ),
          ],
        ),
      ),
    );
  }
}
