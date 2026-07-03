import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/theme/app_palette.dart';
import 'package:smoo_control/features/exchange_rates/domain/repositories/i_exchange_rate_repository.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
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
    this.salesTypes = const [],
    this.selectedSalesTypeId,
    this.onProductsVisibilityToggled,
    this.productsVisible = true,
    this.mobileCatalogMode = false,
    super.key,
  });

  /// Current cart lines.
  final List<PosCartLine> lines;

  /// Available sales types.
  final List<SalesType> salesTypes;

  /// Selected sales type identifier.
  final String? selectedSalesTypeId;

  /// Whether the product catalog is visible below the ticket.
  final bool productsVisible;

  /// Whether phone layout is prioritizing catalog navigation over detail.
  final bool mobileCatalogMode;

  /// Toggles product catalog visibility.
  final VoidCallback? onProductsVisibilityToggled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _ticketMinWidth;
        if (compact && mobileCatalogMode) {
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: _TicketTotalBand(
              hideTotalOnPhone: true,
              lines: lines,
              salesTypes: salesTypes,
              selectedSalesTypeId: selectedSalesTypeId,
              onProductsVisibilityToggled: onProductsVisibilityToggled,
              productsVisible: productsVisible,
            ),
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              if (!compact) ...[
                const _TicketHeader(),
                const Divider(height: 1),
              ],
              Expanded(
                child: ListView.separated(
                  physics: compact && lines.length <= 5
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final line = lines[index];
                    return compact
                        ? _CompactTicketLine(line: line)
                        : _TicketLine(line: line);
                  },
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemCount: lines.length,
                ),
              ),
              _TicketTotalBand(
                lines: lines,
                salesTypes: salesTypes,
                selectedSalesTypeId: selectedSalesTypeId,
                onProductsVisibilityToggled: onProductsVisibilityToggled,
                productsVisible: productsVisible,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactTicketLine extends StatelessWidget {
  const _CompactTicketLine({required this.line});

  final PosCartLine line;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      line.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (line.selectedOptionsLabel.isNotEmpty)
                      AppText(
                        line.selectedOptionsLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        variant: AppTextVariant.label,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppText(
                MoneyFormatter.format(line.totalInCents),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                variant: AppTextVariant.label,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            spacing: 10,
            children: [
              _ServedToggle(line: line),
              _QuantityControls(line: line),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: AppText(
                    MoneyFormatter.format(line.product.priceInCents),
                    variant: AppTextVariant.label,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).removeAction,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => unawaited(_removeLine(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _removeLine(BuildContext context) async {
    final confirmed = await confirmRemovePosLine(context, line: line);
    if (!confirmed || !context.mounted) return;
    context.read<PosBloc>().add(PosProductRemoved(line.lineKey));
  }
}
