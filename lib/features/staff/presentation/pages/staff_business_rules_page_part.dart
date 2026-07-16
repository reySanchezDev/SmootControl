part of 'staff_admin_pages.dart';

/// Admin page for operational business rules.
class BusinessRulesPage extends StatefulWidget {
  /// Creates the page.
  const BusinessRulesPage({super.key});

  @override
  State<BusinessRulesPage> createState() => _BusinessRulesPageState();
}

class _BusinessRulesPageState extends State<BusinessRulesPage> {
  late Future<AppResult<List<BusinessRule>>> _future;

  SupabaseStaffAdminRepository get _repository =>
      serviceLocator<SupabaseStaffAdminRepository>();

  @override
  void initState() {
    super.initState();
    _future = _repository.getBusinessRules();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Reglas del negocio',
      body: FutureBuilder<AppResult<List<BusinessRule>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const AppLoadingPage();
          return switch (snapshot.requireData) {
            AppSuccess(:final value) => _BusinessRulesList(
              rules: value,
              onChanged: _saveRule,
            ),
            AppFailureResult(:final error) => AppEmptyState(
              icon: Icons.rule_outlined,
              title: 'Reglas del negocio',
              message: error.message,
            ),
          };
        },
      ),
    );
  }

  Future<void> _saveRule(BusinessRule rule) async {
    final result = await _repository.saveBusinessRule(rule);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        setState(() => _future = _repository.getBusinessRules());
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }
}

class _BusinessRulesList extends StatelessWidget {
  const _BusinessRulesList({required this.rules, required this.onChanged});

  final List<BusinessRule> rules;
  final ValueChanged<BusinessRule> onChanged;

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
