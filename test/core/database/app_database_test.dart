import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';

void main() {
  group('AppDatabase', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('stores and reads local product categories', () async {
      final now = DateTime(2026, 6, 23);

      await database
          .into(database.localProductCategories)
          .insert(
            LocalProductCategoriesCompanion.insert(
              id: 'category-1',
              name: 'Cafe Caliente',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final categories = await database
          .select(database.localProductCategories)
          .get();

      expect(categories, hasLength(1));
      expect(categories.single.name, 'Cafe Caliente');
      expect(categories.single.syncStatus, 'pending');
    });

    test('stores sync queue entries as pending by default', () async {
      final now = DateTime(2026, 6, 23);

      await database
          .into(database.localSyncQueue)
          .insert(
            LocalSyncQueueCompanion.insert(
              id: 'sync-1',
              entityType: 'sale',
              entityId: 'sale-1',
              operation: 'create',
              payloadJson: '{}',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final entries = await database.select(database.localSyncQueue).get();

      expect(entries.single.status, 'pending');
      expect(entries.single.retryCount, 0);
    });

    test('upgrades staff tables without duplicate deliveredAt', () async {
      await database.close();
      database = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDatabase) {
            rawDatabase
              ..execute('PRAGMA user_version = 23')
              ..execute('''
                CREATE TABLE local_sales (
                  id TEXT NOT NULL PRIMARY KEY,
                  invoice_number TEXT NOT NULL,
                  table_id TEXT,
                  table_account_id TEXT,
                  cash_register_session_id TEXT,
                  payment_method_id TEXT NOT NULL,
                  sales_type_id TEXT,
                  sales_type_name TEXT,
                  payment_reference TEXT,
                  status TEXT NOT NULL DEFAULT 'completed',
                  subtotal_in_cents INTEGER NOT NULL,
                  total_in_cents INTEGER NOT NULL,
                  remote_id TEXT,
                  sync_status TEXT NOT NULL DEFAULT 'pending',
                  sync_error TEXT,
                  created_at INTEGER NOT NULL,
                  updated_at INTEGER NOT NULL,
                  synced_at INTEGER
                )
              ''')
              ..execute('''
                CREATE TABLE local_operating_expenses (
                  id TEXT NOT NULL PRIMARY KEY,
                  category_id TEXT NOT NULL,
                  cash_register_session_id TEXT,
                  amount_in_cents INTEGER NOT NULL,
                  description TEXT NOT NULL,
                  created_by TEXT NOT NULL,
                  remote_id TEXT,
                  sync_status TEXT NOT NULL DEFAULT 'pending',
                  sync_error TEXT,
                  created_at INTEGER NOT NULL,
                  updated_at INTEGER NOT NULL,
                  synced_at INTEGER
                )
              ''')
              ..execute('''
                CREATE TABLE local_expense_categories (
                  id TEXT NOT NULL PRIMARY KEY,
                  name TEXT NOT NULL,
                  parent_id TEXT,
                  is_active INTEGER NOT NULL DEFAULT 1,
                  remote_id TEXT,
                  sync_status TEXT NOT NULL DEFAULT 'pending',
                  sync_error TEXT,
                  created_at INTEGER NOT NULL,
                  updated_at INTEGER NOT NULL,
                  synced_at INTEGER
                )
              ''');
          },
        ),
      );

      final columns = await database
          .customSelect('PRAGMA table_info(local_salary_advances)')
          .get();
      final deliveredAtColumns = columns
          .where((row) => row.data['name'] == 'delivered_at')
          .toList();
      final expenseCategoryColumns = await database
          .customSelect('PRAGMA table_info(local_expense_categories)')
          .get();
      final coverageColumns = expenseCategoryColumns
          .where(
            (row) => row.data['name'] == 'include_in_gross_profit_coverage',
          )
          .toList();

      expect(deliveredAtColumns, hasLength(1));
      expect(coverageColumns, hasLength(1));
      final advances = await database
          .select(database.localSalaryAdvances)
          .get();
      expect(advances, isEmpty);
    });
  });
}
