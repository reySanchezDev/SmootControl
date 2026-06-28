import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Report section with auditable sale void details.
class ReportVoidsSection extends StatelessWidget {
  /// Creates the voids detail section.
  const ReportVoidsSection({required this.voids, super.key});

  /// Voids registered in the selected report period.
  final List<SaleVoid> voids;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (voids.isEmpty) {
      return AppEmptyState(
        icon: Icons.block_outlined,
        message: l10n.reportNoVoids,
        title: l10n.reportVoidsDetail,
      );
    }

    return Column(
      children: [
        for (final saleVoid in voids.take(10)) _VoidTile(saleVoid: saleVoid),
      ],
    );
  }
}

class _VoidTile extends StatelessWidget {
  const _VoidTile({required this.saleVoid});

  final SaleVoid saleVoid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.block_outlined),
      subtitle: AppText(
        '${_formatDate(saleVoid.voidedAt)} - '
        '${l10n.reportVoidBy}: ${_userLabel(l10n, saleVoid.voidedBy)}',
        maxLines: 2,
        variant: AppTextVariant.label,
      ),
      title: AppText(saleVoid.reason, maxLines: 2),
    );
  }

  String _userLabel(AppLocalizations l10n, String value) {
    return value == CurrentOperatorService.localUserId
        ? l10n.localUserLabel
        : value;
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}
