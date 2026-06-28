import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Date selector used by the transactions page.
class SalesDateSelector extends StatelessWidget {
  /// Creates a transactions date selector.
  const SalesDateSelector({
    required this.onChanged,
    required this.selectedDate,
    super.key,
  });

  /// Current business date shown by the page.
  final DateTime selectedDate;

  /// Called when the user picks another date.
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        spacing: 8,
        children: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () {
              unawaited(_selectDate(context));
            },
            tooltip: l10n.reportSelectDate,
          ),
          AppText(
            '${l10n.salesDateLabel}: ${_formatDate(selectedDate)}',
            variant: AppTextVariant.label,
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      initialDate: selectedDate,
      lastDate: DateTime(2100),
    );

    if (picked == null) return;
    onChanged(DateTime(picked.year, picked.month, picked.day));
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
  }
}
