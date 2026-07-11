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
      ],
    );
  }
}
