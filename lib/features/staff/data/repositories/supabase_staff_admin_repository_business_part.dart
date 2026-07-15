part of 'supabase_staff_admin_repository.dart';

mixin _SupabaseStaffBusinessMixin on _SupabaseStaffAdminRepositoryBase {
  Future<AppResult<List<BusinessRule>>> getBusinessRules() {
    return _guard(
      'business_rules_read_failed',
      'No se pudieron leer reglas del negocio.',
      () async {
        final rows = await _getRows('business_rules', {
          'restaurant_id': 'eq.$_restaurantId',
          'select': 'key,bool_value,text_value',
          'order': 'key.asc',
        });
        if (rows.isEmpty) {
          return const [
            BusinessRule(
              key: BusinessRule.salaryAdvancePosAffectsCash,
              boolValue: false,
            ),
            BusinessRule(key: BusinessRule.overtimeHourRate, textValue: '0'),
          ];
        }
        return rows.map(_ruleFromRow).toList();
      },
    );
  }

  Future<AppResult<BusinessRule>> saveBusinessRule(BusinessRule rule) {
    return _guard(
      'business_rule_save_failed',
      'No se pudo guardar la regla del negocio.',
      () async {
        await _upsert(
          'business_rules',
          {
            'restaurant_id': _restaurantId,
            'key': rule.key,
            'bool_value': rule.boolValue,
            'text_value': rule.textValue,
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictColumn: 'restaurant_id,key',
        );
        return rule;
      },
    );
  }
}
