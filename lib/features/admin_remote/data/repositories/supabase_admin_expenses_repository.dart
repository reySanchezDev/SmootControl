import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/domain/entities/operating_expense.dart';
import 'package:smoo_control/features/expenses/domain/repositories/i_expenses_repository.dart';

part 'supabase_admin_expenses_repository_support.dart';

/// Remote-only expenses repository used by administrative screens.
final class SupabaseAdminExpensesRepository implements IExpensesRepository {
  /// Creates the repository.
  const SupabaseAdminExpensesRepository({
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
  }) : _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client;

  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final CurrentRemoteSessionService _remoteSessionService;
  final http.Client _client;

  @override
  Future<AppResult<List<ExpenseCategory>>> getCategories() async {
    return _guard(
      'expense_categories_read_failed',
      'No se pudieron leer categorias de gastos.',
      () async {
        final rows = await _getRows('expense_categories', {
          'restaurant_id': 'eq.$_restaurantId',
          'select':
              'id,parent_id,name,is_active,include_in_gross_profit_coverage,'
              'coverage_expense_type,coverage_estimated_amount,'
              'coverage_frequency,coverage_due_days,coverage_notes,'
              'coverage_is_active',
          'order': 'name.asc',
        });
        return rows
            .map(
              (row) => ExpenseCategory(
                id: _text(row['id']),
                name: _text(row['name']),
                parentId: _nullableText(row['parent_id']),
                isActive: _bool(row['is_active'], fallback: true),
                includeInGrossProfitCoverage: _bool(
                  row['include_in_gross_profit_coverage'],
                ),
                coverageType: _coverageType(row['coverage_expense_type']),
                coverageEstimatedAmountInCents: _nullableMoneyToCents(
                  row['coverage_estimated_amount'],
                ),
                coverageFrequency: _coverageFrequency(
                  row['coverage_frequency'],
                ),
                coverageDueDays: _intList(row['coverage_due_days']),
                coverageNotes: _nullableText(row['coverage_notes']),
                coverageIsActive: _bool(
                  row['coverage_is_active'],
                  fallback: true,
                ),
              ),
            )
            .toList();
      },
    );
  }

  @override
  Future<AppResult<List<OperatingExpense>>> getExpenses({
    required DateTime from,
    required DateTime to,
  }) async {
    return _guard(
      'expenses_read_failed',
      'No se pudieron leer gastos.',
      () async {
        final rows = await _getRows('operating_expenses', {
          'restaurant_id': 'eq.$_restaurantId',
          'and':
              '(spent_at.gte.${from.toIso8601String()},'
              'spent_at.lt.${to.toIso8601String()})',
          'select':
              'id,expense_category_id,cash_register_session_id,amount,'
              'description,created_by_user_id,spent_at',
          'order': 'spent_at.desc',
        });
        return rows
            .map(
              (row) => OperatingExpense(
                id: _text(row['id']),
                categoryId: _text(row['expense_category_id']),
                cashRegisterSessionId: _nullableText(
                  row['cash_register_session_id'],
                ),
                amountInCents: _moneyToCents(row['amount']),
                description: _text(row['description']),
                createdBy: _text(row['created_by_user_id']),
                createdAt: _date(row['spent_at']),
              ),
            )
            .toList();
      },
    );
  }

  @override
  Future<AppResult<ExpenseCategory>> saveCategory(
    ExpenseCategory category,
  ) async {
    return _guard(
      'expense_category_save_failed',
      'No se pudo guardar categoria de gasto.',
      () async {
        final normalized = _normalizedCategory(category);
        await _upsert('expense_categories', {
          'id': normalized.id,
          'restaurant_id': _restaurantId,
          'parent_id': normalized.parentId,
          'name': normalized.name,
          'is_active': normalized.isActive,
          'include_in_gross_profit_coverage':
              normalized.includeInGrossProfitCoverage,
          'coverage_expense_type': normalized.coverageType?.name,
          'coverage_estimated_amount':
              normalized.coverageEstimatedAmountInCents == null
              ? null
              : _money(normalized.coverageEstimatedAmountInCents!),
          'coverage_frequency': normalized.coverageFrequency?.name,
          'coverage_due_days': normalized.coverageDueDays,
          'coverage_notes': normalized.coverageNotes,
          'coverage_is_active': normalized.coverageIsActive,
          'updated_at': DateTime.now().toIso8601String(),
        });
        return normalized;
      },
    );
  }

  @override
  Future<AppResult<void>> deleteCategory(String categoryId) async {
    return _guard(
      'expense_category_delete_failed',
      'No se pudo eliminar categoria de gasto.',
      () async {
        await _patchWhere(
          'expense_categories',
          {
            'parent_id': null,
            'updated_at': DateTime.now().toIso8601String(),
          },
          {'parent_id': 'eq.$categoryId'},
        );
        await _deleteWhere('expense_categories', {'id': 'eq.$categoryId'});
      },
    );
  }

  @override
  Future<AppResult<OperatingExpense>> saveExpense(
    OperatingExpense expense,
  ) async {
    return _guard('expense_save_failed', 'No se pudo guardar gasto.', () async {
      await _upsert('operating_expenses', {
        'id': expense.id,
        'local_id': expense.id,
        'restaurant_id': _restaurantId,
        'expense_category_id': expense.categoryId,
        'cash_register_session_id': expense.cashRegisterSessionId,
        'created_by_user_id': _remoteUserId,
        'description': expense.description,
        'amount': _money(expense.amountInCents),
        'sync_status': 'synced',
        'spent_at': expense.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return expense;
    });
  }

  Future<AppResult<T>> _guard<T>(
    String code,
    String message,
    Future<T> Function() action,
  ) async {
    try {
      if (!_config.isConfigured ||
          !_restaurantService.isConfigured ||
          _remoteSessionService.accessToken == null) {
        throw StateError('Se requiere sesion administrativa remota.');
      }
      return AppSuccess(await action());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(code: code, message: message, cause: error),
      );
    }
  }

  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> query,
  ) async {
    final response = await _client.get(
      _config.restUri(table, query),
      headers: _headers(),
    );
    _ensureSuccess(response, table);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<Object?, Object?>>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  Future<void> _upsert(
    String table,
    Map<String, Object?> payload, {
    String conflictColumn = 'id',
  }) async {
    final response = await _client.post(
      _config.restUri(table, {'on_conflict': conflictColumn}),
      headers: _headers(prefer: 'resolution=merge-duplicates,return=minimal'),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, table);
  }

  Future<void> _patchWhere(
    String table,
    Map<String, Object?> payload,
    Map<String, String> query,
  ) async {
    final response = await _client.patch(
      _config.restUri(table, query),
      headers: _headers(prefer: 'return=minimal'),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, table);
  }

  Future<void> _deleteWhere(String table, Map<String, String> query) async {
    final response = await _client.delete(
      _config.restUri(table, query),
      headers: _headers(prefer: 'return=minimal'),
    );
    _ensureSuccess(response, table);
  }

  Map<String, String> _headers({String? prefer}) {
    final token = _remoteSessionService.accessToken;
    if (token == null) throw StateError('Sesion remota expirada.');
    return {
      'apikey': _config.publishableKey,
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      'accept': 'application/json',
      // ignore: use_null_aware_elements, SDK infers String? as map value.
      if (prefer case final value?) 'prefer': value,
    };
  }

  void _ensureSuccess(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      _remoteSessionService.expire();
    }
    throw StateError(
      'Supabase rechazo $operation (${response.statusCode}): ${response.body}',
    );
  }

  String get _restaurantId => _restaurantService.restaurantId;

  String get _remoteUserId {
    final userId = _remoteSessionService.userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('No se pudo resolver el administrador remoto.');
    }
    return userId;
  }
}
