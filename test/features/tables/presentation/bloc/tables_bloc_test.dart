import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/features/tables/domain/entities/table_account.dart';
import 'package:smoo_control/features/tables/domain/repositories/i_tables_repository.dart';
import 'package:smoo_control/features/tables/presentation/bloc/tables_bloc.dart';
import 'package:smoo_control/features/tables/presentation/bloc/tables_event.dart';
import 'package:smoo_control/features/tables/presentation/bloc/tables_state.dart';

void main() {
  group('TablesBloc', () {
    const table = RestaurantTable(
      id: 'table-1',
      name: 'Mesa 1',
      status: RestaurantTableStatus.available,
      isActive: true,
    );

    blocTest<TablesBloc, TablesState>(
      'loads tables',
      build: () => TablesBloc(
        repository: _TablesRepositoryFake(
          tablesResult: const AppSuccess([table]),
        ),
        auditLogRepository: _AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(const TablesLoadRequested()),
      expect: () => const [
        TablesLoading(),
        TablesLoaded([table]),
      ],
    );

    blocTest<TablesBloc, TablesState>(
      'emits failure when loading fails',
      build: () => TablesBloc(
        repository: _TablesRepositoryFake(
          tablesResult: const AppFailureResult(
            AppFailure(code: 'tables_error', message: 'Error'),
          ),
        ),
        auditLogRepository: _AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(const TablesLoadRequested()),
      expect: () => const [
        TablesLoading(),
        TablesFailure(AppFailure(code: 'tables_error', message: 'Error')),
      ],
    );

    late _AuditLogRepositoryFake auditRepository;

    blocTest<TablesBloc, TablesState>(
      'audits table save',
      build: () {
        auditRepository = _AuditLogRepositoryFake();

        return TablesBloc(
          repository: _TablesRepositoryFake(
            tablesResult: const AppSuccess([table]),
          ),
          auditLogRepository: auditRepository,
        );
      },
      act: (bloc) => bloc.add(const TableSaved(table)),
      expect: () => const [
        TablesLoading(),
        TablesLoaded([table]),
      ],
      verify: (_) {
        expect(auditRepository.entries.single.action, 'tables.save');
        expect(auditRepository.entries.single.entityId, table.id);
        expect(
          auditRepository.entries.single.details['status'],
          RestaurantTableStatus.available.name,
        );
      },
    );
  });
}

final class _TablesRepositoryFake implements ITablesRepository {
  _TablesRepositoryFake({
    required this.tablesResult,
  });

  final AppResult<List<RestaurantTable>> tablesResult;

  @override
  Future<AppResult<List<RestaurantTable>>> getTables() async {
    return tablesResult;
  }

  @override
  Future<AppResult<RestaurantTable>> saveTable(RestaurantTable table) async {
    return AppSuccess(table);
  }

  @override
  Future<AppResult<List<TableAccount>>> getTableAccounts(String tableId) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<List<TableAccount>>> saveTableAccounts(
    List<TableAccount> accounts,
  ) async {
    return AppSuccess(accounts);
  }
}

final class _AuditLogRepositoryFake implements IAuditLogRepository {
  final List<AuditLogEntry> entries = [];

  @override
  Future<AppResult<List<AuditLogEntry>>> getEntriesByDate(DateTime date) async {
    return AppSuccess(entries);
  }

  @override
  Future<AppResult<AuditLogEntry>> saveEntry(AuditLogEntry entry) async {
    entries.add(entry);
    return AppSuccess(entry);
  }
}
