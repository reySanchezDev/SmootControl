part of 'measurement_units_page.dart';

class _MeasurementUnitDraft {
  _MeasurementUnitDraft(this.unit)
    : code = unit?.code ?? '',
      name = unit?.name ?? '',
      group = unit?.unitGroup ?? 'count',
      factor = (unit?.baseFactor ?? 1).toString();

  final MeasurementUnit? unit;
  String code;
  String name;
  String group;
  String factor;
}

class _MeasurementUnitDialog extends StatefulWidget {
  const _MeasurementUnitDialog({required this.onSave, this.unit});

  final MeasurementUnit? unit;
  final Future<String?> Function(_MeasurementUnitDraft draft) onSave;

  @override
  State<_MeasurementUnitDialog> createState() => _MeasurementUnitDialogState();
}

class _MeasurementUnitDialogState extends State<_MeasurementUnitDialog> {
  late final _MeasurementUnitDraft _draft;
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _factor;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = _MeasurementUnitDraft(widget.unit);
    _code = TextEditingController(text: _draft.code);
    _name = TextEditingController(text: _draft.name);
    _factor = TextEditingController(text: _draft.factor);
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _factor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.unit == null ? 'Nueva unidad' : 'Editar unidad'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Codigo'),
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _draft.group,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'count', child: Text('Conteo')),
                DropdownMenuItem(value: 'mass', child: Text('Masa')),
                DropdownMenuItem(value: 'volume', child: Text('Volumen')),
              ],
              onChanged: (value) => _draft.group = value ?? 'count',
            ),
            TextField(
              controller: _factor,
              decoration: const InputDecoration(labelText: 'Factor base'),
            ),
            if (_error != null) AppText(_error!, maxLines: 3),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          primary: false,
          onPressed: _saving ? null : () => Navigator.pop(context, false),
        ),
        AppButton(
          label: _saving ? 'Guardando' : 'Guardar',
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    _draft
      ..code = _code.text
      ..name = _name.text
      ..factor = _factor.text;
    final error = await widget.onSave(_draft);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _error = error;
      _saving = false;
    });
  }
}
