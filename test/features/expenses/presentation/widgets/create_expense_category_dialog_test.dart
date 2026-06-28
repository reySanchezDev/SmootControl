import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/presentation/widgets/create_expense_category_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('edits expense category keeping the same system id', (
    tester,
  ) async {
    ExpenseCategory? savedCategory;
    const category = ExpenseCategory(
      id: 'expense-category-1',
      name: 'Nomina',
      isActive: true,
    );

    await _pumpDialog(
      tester,
      category: category,
      onSaved: (category) => savedCategory = category,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Edit expense category'), findsOneWidget);
    expect(find.text('Expense category ID'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Planilla');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedCategory?.id, 'expense-category-1');
    expect(savedCategory?.name, 'Planilla');
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  ExpenseCategory? category,
  ValueChanged<ExpenseCategory>? onSaved,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<ExpenseCategory>(
                context: context,
                builder: (_) => CreateExpenseCategoryDialog(
                  category: category,
                ),
              );

              if (result != null) {
                onSaved?.call(result);
              }
            },
            child: const Text('Open dialog'),
          ),
        ),
      ),
    ),
  );
}
