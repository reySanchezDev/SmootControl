import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Table selector used by the POS checkout flow.
class PosTableSelector extends StatelessWidget {
  /// Creates a table selector.
  const PosTableSelector({
    required this.selectedTableId,
    required this.tables,
    super.key,
  });

  /// Selected table identifier.
  final String? selectedTableId;

  /// Active restaurant tables.
  final List<RestaurantTable> tables;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<String?>(
      decoration: InputDecoration(labelText: l10n.tableField),
      initialValue: selectedTableId,
      items: [
        DropdownMenuItem<String?>(child: AppText(l10n.noTableOption)),
        for (final table in tables)
          DropdownMenuItem<String?>(
            value: table.id,
            child: AppText(table.name),
          ),
      ],
      onChanged: (value) {
        context.read<PosBloc>().add(PosTableSelected(value));
      },
    );
  }
}
