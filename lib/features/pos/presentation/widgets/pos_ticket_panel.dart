import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/theme/app_palette.dart';
import 'package:smoo_control/features/exchange_rates/domain/repositories/i_exchange_rate_repository.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_danger_confirmation.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'pos_ticket_panel_parts.dart';
part 'pos_ticket_total_band.dart';

/// Ticket table displayed at the top of the POS.
class PosTicketPanel extends StatelessWidget {
  /// Creates the ticket panel.
  const PosTicketPanel({
    required this.lines,
    this.onProductsVisibilityToggled,
    this.productsVisible = true,
    super.key,
  });

  /// Current cart lines.
  final List<PosCartLine> lines;

  /// Whether the product catalog is visible below the ticket.
  final bool productsVisible;

  /// Toggles product catalog visibility.
  final VoidCallback? onProductsVisibilityToggled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const _TicketHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemBuilder: (context, index) {
                return _TicketLine(line: lines[index]);
              },
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemCount: lines.length,
            ),
          ),
          _TicketTotalBand(
            lines: lines,
            onProductsVisibilityToggled: onProductsVisibilityToggled,
            productsVisible: productsVisible,
          ),
        ],
      ),
    );
  }
}
