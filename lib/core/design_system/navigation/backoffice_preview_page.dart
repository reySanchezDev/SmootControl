import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/navigation/backoffice_workspace.dart';

/// Visual-only preview of the Backoffice V2 shell.
///
/// Uses illustrative data, never production services or repositories.
class BackofficePreviewPage extends StatelessWidget {
  /// Creates the isolated visual preview.
  const BackofficePreviewPage({super.key});

  static const _destinations = <BackofficeWorkspaceItem>[
    BackofficeWorkspaceItem(
      id: 'overview',
      label: 'Inicio',
      route: '/',
      icon: Icons.dashboard_outlined,
      group: 'Principal',
    ),
    BackofficeWorkspaceItem(
      id: 'products',
      label: 'Productos',
      route: '/products',
      icon: Icons.inventory_2_outlined,
      group: 'Catálogos',
    ),
    BackofficeWorkspaceItem(
      id: 'inventory',
      label: 'Inventario',
      route: '/inventory',
      icon: Icons.warehouse_outlined,
      group: 'Operación',
    ),
    BackofficeWorkspaceItem(
      id: 'sales',
      label: 'Ventas',
      route: '/sales',
      icon: Icons.receipt_long_outlined,
      group: 'Operación',
    ),
    BackofficeWorkspaceItem(
      id: 'staff',
      label: 'Personal',
      route: '/staff',
      icon: Icons.groups_outlined,
      group: 'Administración',
    ),
    BackofficeWorkspaceItem(
      id: 'reports',
      label: 'Reportes',
      route: '/reports',
      icon: Icons.bar_chart_outlined,
      group: 'Reportes',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BackofficeWorkspace(
      items: _destinations,
      pageBuilder: (context, item) => _PreviewCanvas(item: item),
    );
  }
}

class _PreviewCanvas extends StatefulWidget {
  const _PreviewCanvas({required this.item});

  final BackofficeWorkspaceItem item;

  @override
  State<_PreviewCanvas> createState() => _PreviewCanvasState();
}

class _PreviewCanvasState extends State<_PreviewCanvas> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const sample = ['Café americano', 'Agua 1L', 'Arroz', 'Bistec'];
    final filtered = sample
        .where((entry) => entry.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'VISTA PREVIA · DATOS ILUSTRATIVOS',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 12),
          Text(widget.item.label, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Esta vista demuestra el espacio de trabajo; '
            'no consulta ni modifica información del restaurante.',
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar en esta pestaña',
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                for (final entry in filtered)
                  ListTile(
                    title: Text(entry),
                    subtitle: const Text('Registro ilustrativo'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No hay coincidencias en el ejemplo.'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
