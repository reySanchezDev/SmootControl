part of 'staff_admin_pages.dart';

/// Admin page for employee positions.
class StaffPositionsPage extends StatefulWidget {
  /// Creates the page.
  const StaffPositionsPage({super.key});

  @override
  State<StaffPositionsPage> createState() => _StaffPositionsPageState();
}

class _StaffPositionsPageState extends State<StaffPositionsPage> {
  late Future<AppResult<List<EmployeePosition>>> _future;

  SupabaseStaffAdminRepository get _repository =>
      serviceLocator<SupabaseStaffAdminRepository>();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repository.getPositions();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Puestos',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => unawaited(_editPosition()),
        ),
      ],
      body: FutureBuilder<AppResult<List<EmployeePosition>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const AppLoadingPage();
          return switch (snapshot.requireData) {
            AppSuccess(:final value) => _PositionList(
              positions: value,
              onEdit: (position) => unawaited(_editPosition(position)),
            ),
            AppFailureResult(:final error) => AppEmptyState(
              icon: Icons.work_outline,
              title: 'Puestos',
              message: error.message,
            ),
          };
        },
      ),
    );
  }

  Future<void> _editPosition([EmployeePosition? position]) async {
    final result = await showDialog<EmployeePosition>(
      context: context,
      builder: (_) => _PositionDialog(position: position),
    );
    if (result == null || !mounted) return;
    final saved = await _repository.savePosition(result);
    if (!mounted) return;
    switch (saved) {
      case AppSuccess():
        setState(_reload);
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }
}

class _PositionList extends StatelessWidget {
  const _PositionList({required this.positions, required this.onEdit});

  final List<EmployeePosition> positions;
  final ValueChanged<EmployeePosition> onEdit;

  @override
  Widget build(BuildContext context) {
    if (positions.isEmpty) {
      return const AppEmptyState(
        icon: Icons.work_outline,
        title: 'Sin puestos',
        message: 'Los puestos registrados apareceran aqui.',
      );
    }
    return ListView.separated(
      itemCount: positions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final position = positions[index];
        return ListTile(
          leading: Icon(
            position.isActive ? Icons.work_outline : Icons.block_outlined,
          ),
          title: Text(position.name),
          subtitle: Text(position.isActive ? 'Activo' : 'Inactivo'),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => onEdit(position),
        );
      },
    );
  }
}

class _PositionDialog extends StatefulWidget {
  const _PositionDialog({this.position});

  final EmployeePosition? position;

  @override
  State<_PositionDialog> createState() => _PositionDialogState();
}

class _PositionDialogState extends State<_PositionDialog> {
  late final _name = TextEditingController(
    text: widget.position?.name ?? '',
  );
  late bool _active = widget.position?.isActive ?? true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.position == null ? 'Nuevo puesto' : 'Editar puesto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activo'),
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Indica el nombre del puesto.');
      return;
    }
    Navigator.of(context).pop(
      EmployeePosition(
        id: widget.position?.id ?? '',
        name: name,
        displayOrder: widget.position?.displayOrder ?? 0,
        isActive: _active,
      ),
    );
  }
}
