part of 'payment_methods_page.dart';

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.depth,
    required this.method,
  });

  final int depth;
  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final details = [
      if (method.isPaymentTarget)
        l10n.paymentFinalOptionField
      else
        l10n.paymentNavigationNode,
      if (method.currencyCode != null) method.currencyCode!,
      if (method.isActive) l10n.activeStatus else l10n.inactiveStatus,
      if (method.affectsCashRegister) l10n.cashAffectsRegister,
      if (method.requiresReference) l10n.requiresReference,
    ].join(' - ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return ListTile(
          contentPadding: EdgeInsets.only(left: 16 + (depth * 24), right: 16),
          leading: Icon(
            method.isPaymentTarget
                ? Icons.payments_outlined
                : Icons.folder_open,
          ),
          subtitle: AppText(
            details,
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            variant: AppTextVariant.label,
          ),
          title: AppText(
            method.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

        );
      },
    );
  }
}
