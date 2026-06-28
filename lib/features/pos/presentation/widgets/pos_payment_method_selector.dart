import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Payment method selector used by the non-split POS checkout flow.
class PosPaymentMethodSelector extends StatelessWidget {
  /// Creates the payment method selector.
  const PosPaymentMethodSelector({
    required this.methods,
    required this.selectedPaymentMethodId,
    super.key,
  });

  /// Available payment methods.
  final List<PaymentMethod> methods;

  /// Currently selected payment method.
  final String? selectedPaymentMethodId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: l10n.paymentMethodField),
      initialValue: selectedPaymentMethodId,
      items: [
        for (final method in methods)
          DropdownMenuItem(
            value: method.id,
            child: AppText(method.name),
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          context.read<PosBloc>().add(PosPaymentMethodSelected(value));
        }
      },
    );
  }
}
