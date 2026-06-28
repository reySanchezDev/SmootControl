import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/domain/entities/operating_expense.dart';
import 'package:smoo_control/features/expenses/presentation/widgets/create_expense_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    serviceLocator.registerLazySingleton<CurrentOperatorService>(
      CurrentOperatorService.new,
    );
  });

  tearDown(() async {
    await serviceLocator.reset();
  });

  testWidgets('uses the centralized local operator when saving an expense', (
    tester,
  ) async {
    OperatingExpense? savedExpense;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await showDialog<OperatingExpense>(
                  context: context,
                  builder: (_) => const CreateExpenseDialog(
                    cashRegisterSessionId: 'cash-session-1',
                    categories: [
                      ExpenseCategory(
                        id: 'expense-category-1',
                        name: 'Varios',
                        isActive: true,
                      ),
                    ],
                  ),
                );

                savedExpense = result;
              },
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Varios').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '25');
    await tester.enterText(find.byType(TextField).at(1), 'Compra local');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedExpense?.createdBy, CurrentOperatorService.localUserId);
    expect(savedExpense?.cashRegisterSessionId, 'cash-session-1');
    expect(savedExpense?.amountInCents, 2500);
  });
}
