import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/payment_methods/presentation/widgets/create_payment_method_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('creates a chargeable account under a payment parent', (
    tester,
  ) async {
    PaymentMethod? savedMethod;

    await _pumpDialog(
      tester,
      methods: const [_transferRoot, _banpro],
      onSaved: (method) => savedMethod = method,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Cuenta 7888889');
    await tester.tap(find.text('Top level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferencias > BANPRO').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chargeable POS option'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Requires reference'));
    await tester.tap(find.text('Requires reference'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedMethod?.name, 'Cuenta 7888889');
    expect(savedMethod?.parentId, 'banpro');
    expect(savedMethod?.groupName, 'Transferencias');
    expect(savedMethod?.isPaymentTarget, isTrue);
    expect(savedMethod?.requiresReference, isTrue);
  });

  testWidgets('edits payment method keeping the same system id', (
    tester,
  ) async {
    PaymentMethod? savedMethod;
    const method = PaymentMethod(
      id: 'transfer',
      name: 'Transferencia',
      affectsCashRegister: false,
      requiresReference: true,
      isActive: true,
    );

    await _pumpDialog(
      tester,
      method: method,
      onSaved: (method) => savedMethod = method,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Edit payment method'), findsOneWidget);
    expect(find.text('Payment method ID'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Tarjeta');
    await tester.tap(find.text('Affects cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedMethod?.id, 'transfer');
    expect(savedMethod?.name, 'Tarjeta');
    expect(savedMethod?.affectsCashRegister, isTrue);
    expect(savedMethod?.requiresReference, isTrue);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  PaymentMethod? method,
  List<PaymentMethod> methods = const [],
  ValueChanged<PaymentMethod>? onSaved,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<PaymentMethod>(
                context: context,
                builder: (_) => CreatePaymentMethodDialog(
                  method: method,
                  methods: methods,
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

const _transferRoot = PaymentMethod(
  id: 'transfer-root',
  name: 'Transferencias',
  groupName: 'Transferencias',
  affectsCashRegister: false,
  requiresReference: false,
  isPaymentTarget: false,
  isActive: true,
);

const _banpro = PaymentMethod(
  id: 'banpro',
  name: 'BANPRO',
  parentId: 'transfer-root',
  groupName: 'Transferencias',
  affectsCashRegister: false,
  requiresReference: false,
  isPaymentTarget: false,
  isActive: true,
);
