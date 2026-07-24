part of 'staff_admin_pages.dart';

/// Admin page for operational business rules.
class BusinessRulesPage extends StatefulWidget {
  /// Creates the page.
  const BusinessRulesPage({super.key});

  @override
  State<BusinessRulesPage> createState() => _BusinessRulesPageState();
}

class _BusinessRulesPageState extends State<BusinessRulesPage> {
  late Future<({List<BusinessRule> rules, List<EmployeeWorkShift> shifts})>
  _future;

  SupabaseStaffAdminRepository get _repository =>
      serviceLocator<SupabaseStaffAdminRepository>();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<BusinessRule> rules, List<EmployeeWorkShift> shifts})>
  _load() async {
    final rules = await _repository.getBusinessRules();
    final shifts = await _repository.getWorkShifts();
    return (
      rules: switch (rules) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
      shifts: switch (shifts) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Reglas del negocio',
      body:
          FutureBuilder<
            ({List<BusinessRule> rules, List<EmployeeWorkShift> shifts})
          >(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppEmptyState(
                  icon: Icons.rule_outlined,
                  title: 'Reglas del negocio',
                  message: snapshot.error.toString(),
                );
              }
              if (!snapshot.hasData) return const AppLoadingPage();
              final data = snapshot.requireData;
              return _BusinessRulesList(
                rules: data.rules,
                shifts: data.shifts,
                onChanged: _saveRule,
                onShiftChanged: _saveShift,
              );
            },
          ),
    );
  }

  Future<void> _saveRule(BusinessRule rule) async {
    final result = await _repository.saveBusinessRule(rule);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Regla guardada.')),
        );
        setState(() => _future = _load());
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }

  Future<void> _saveShift(EmployeeWorkShift shift) async {
    final result = await _repository.saveWorkShift(shift);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turno guardado.')),
        );
        setState(() => _future = _load());
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }
}

class _BusinessRulesList extends StatelessWidget {
  const _BusinessRulesList({
    required this.rules,
    required this.shifts,
    required this.onChanged,
    required this.onShiftChanged,
  });

  final List<BusinessRule> rules;
  final List<EmployeeWorkShift> shifts;
  final ValueChanged<BusinessRule> onChanged;
  final ValueChanged<EmployeeWorkShift> onShiftChanged;

  @override
  Widget build(BuildContext context) {
    final rule = rules.firstWhere(
      (item) => item.key == BusinessRule.salaryAdvancePosAffectsCash,
      orElse: () => const BusinessRule(
        key: BusinessRule.salaryAdvancePosAffectsCash,
        boolValue: false,
      ),
    );
    final overtimeRule = rules.firstWhere(
      (item) => item.key == BusinessRule.overtimeHourRate,
      orElse: () => const BusinessRule(
        key: BusinessRule.overtimeHourRate,
        textValue: '0',
      ),
    );
    final recipeNegativeRule = rules.firstWhere(
      (item) =>
          item.key == BusinessRule.allowRawMaterialNegativeStockFromRecipes,
      orElse: () => const BusinessRule(
        key: BusinessRule.allowRawMaterialNegativeStockFromRecipes,
        boolValue: true,
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          value: rule.boolValue ?? false,
          title: const Text('Adelantos POS afectan caja'),
          subtitle: const Text(
            'Si esta apagado, el dinero se considera entregado desde '
            'cuenta externa.',
          ),
          onChanged: (value) => onChanged(
            BusinessRule(key: rule.key, boolValue: value),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: recipeNegativeRule.boolValue ?? true,
          title: const Text('Permitir materia prima negativa por recetas'),
          subtitle: const Text(
            'Si esta apagado, Supabase rechazara ventas cuya receta deje '
            'materia prima en negativo.',
          ),
          onChanged: (value) => onChanged(
            BusinessRule(key: recipeNegativeRule.key, boolValue: value),
          ),
        ),
        const SizedBox(height: 12),
        _WorkShiftSection(shifts: shifts, onChanged: onShiftChanged),
        const SizedBox(height: 12),
        _OvertimeRateTile(rule: overtimeRule, onChanged: onChanged),
      ],
    );
  }
}

class _OvertimeRateTile extends StatefulWidget {
  const _OvertimeRateTile({required this.rule, required this.onChanged});

  final BusinessRule rule;
  final ValueChanged<BusinessRule> onChanged;

  @override
  State<_OvertimeRateTile> createState() => _OvertimeRateTileState();
}

class _OvertimeRateTileState extends State<_OvertimeRateTile> {
  late final _controller = TextEditingController(
    text: widget.rule.textValue ?? '0',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Valor hora extra'),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                prefixText: r'C$ ',
                errorText: _error,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*[\.,]?\d{0,2}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar'),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final value = _controller.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(value);
    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Ingresa un valor mayor que cero.';
      });
      return;
    }
    setState(() => _error = null);
    widget.onChanged(
      BusinessRule(key: BusinessRule.overtimeHourRate, textValue: value),
    );
  }
}
