import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';
import 'package:smoo_control/features/modifiers/presentation/widgets/modifier_group_tile.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('compact modifier commands invoke original actions', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    var addCount = 0;
    var editGroupCount = 0;
    var deactivatedGroupCount = 0;
    var editOptionCount = 0;
    var deactivatedOptionCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ModifierGroupTile(
            group: const ModifierGroup(id: 'group', name: 'Salsas'),
            options: const [
              ModifierOption(
                id: 'option',
                groupId: 'group',
                name: 'Salsa picante',
              ),
            ],
            onAddOption: () => addCount++,
            onEditGroup: () => editGroupCount++,
            onDeactivateGroup: () => deactivatedGroupCount++,
            onEditOption: (_) => editOptionCount++,
            onDeactivateOption: (_) => deactivatedOptionCount++,
          ),
        ),
      ),
    );

    expect(find.byType(PopupMenuButton), findsNothing);
    await tester.tap(find.text('Salsas'));
    await tester.pumpAndSettle();

    final labels = AppLocalizations.of(
      tester.element(find.byType(ModifierGroupTile)),
    );
    final add = find.widgetWithText(
      OutlinedButton,
      labels.addModifierOptionAction,
    );
    final edit = find.widgetWithText(OutlinedButton, labels.editAction);
    final deactivate = find.widgetWithText(
      OutlinedButton,
      labels.deactivateAction,
    );

    expect(add, findsOneWidget);
    expect(edit, findsNWidgets(2));
    expect(deactivate, findsNWidgets(2));
    expect(find.byType(PopupMenuButton), findsNothing);

    await tester.tap(add);
    await tester.pump();
    expect(addCount, 1);

    await tester.tap(edit.first);
    await tester.pump();
    expect(editGroupCount, 1);

    await tester.ensureVisible(edit.last);
    await tester.tap(edit.last);
    await tester.pump();
    expect(editOptionCount, 1);

    await tester.tap(deactivate.first);
    await tester.pump();
    expect(deactivatedGroupCount, 1);

    await tester.ensureVisible(deactivate.last);
    await tester.tap(deactivate.last);
    await tester.pump();
    expect(deactivatedOptionCount, 1);
    expect(tester.takeException(), isNull);
  });
}
