import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_split_account_name_input.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_split_accounts_header.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_split_accounts_items.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item_draft.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Editable account used by the split-account workspace.
final class SplitAccountEditor {
  /// Creates an editable split account.
  SplitAccountEditor({
    required this.id,
    required this.controller,
    required this.placeholder,
  });

  /// Stable account identifier.
  final String id;

  /// Account name controller.
  final TextEditingController controller;

  /// Suggested account name shown as a placeholder.
  final String placeholder;
}

/// Fixed original order panel.
class SplitOriginalOrderPanel extends StatelessWidget {
  /// Creates the original order panel.
  const SplitOriginalOrderPanel({
    required this.title,
    required this.compact,
    required this.items,
    required this.panelWidth,
    required this.selectedItemIds,
    required this.onAccept,
    required this.onPanelTap,
    required this.onTapItem,
    required this.onAddAccount,
    required this.onCancel,
    required this.onConfirm,
    super.key,
  });

  /// Panel title.
  final String title;

  /// Whether the panel should use tighter spacing.
  final bool compact;

  /// Items still in the original order.
  final List<SaleItemDraft> items;

  /// Responsive panel width.
  final double panelWidth;

  /// Current selected item identifiers.
  final Set<String> selectedItemIds;

  /// Accepts a returned item.
  final ValueChanged<SaleItemDraft> onAccept;

  /// Moves selected items to this panel.
  final VoidCallback onPanelTap;

  /// Selects one item.
  final ValueChanged<SaleItemDraft> onTapItem;

  /// Adds a new split account.
  final VoidCallback onAddAccount;

  /// Cancels the split flow.
  final VoidCallback onCancel;

  /// Confirms the split flow.
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return _SplitPanelFrame(
      panelKey: const ValueKey('split-original-panel'),
      header: SplitOriginalHeader(
        compact: compact,
        title: title,
        onAddAccount: onAddAccount,
        onCancel: onCancel,
        onConfirm: onConfirm,
      ),
      items: items,
      compact: compact,
      panelWidth: panelWidth,
      selectedItemIds: selectedItemIds,
      onAccept: onAccept,
      onPanelTap: onPanelTap,
      onTapItem: onTapItem,
    );
  }
}

/// Split account panel.
class SplitAccountPanel extends StatelessWidget {
  /// Creates an account panel.
  const SplitAccountPanel({
    required this.account,
    required this.canRemove,
    required this.compact,
    required this.items,
    required this.panelWidth,
    required this.selectedItemIds,
    required this.onAccept,
    required this.onPanelTap,
    required this.onRemoveAccount,
    required this.onTapItem,
    super.key,
  });

  /// Editable account data.
  final SplitAccountEditor account;

  /// Whether the account can be removed.
  final bool canRemove;

  /// Whether the panel should use tighter spacing.
  final bool compact;

  /// Items assigned to this account.
  final List<SaleItemDraft> items;

  /// Responsive panel width.
  final double panelWidth;

  /// Current selected item identifiers.
  final Set<String> selectedItemIds;

  /// Accepts one moved item.
  final ValueChanged<SaleItemDraft> onAccept;

  /// Assigns selected item to this panel.
  final VoidCallback onPanelTap;

  /// Removes the account.
  final VoidCallback onRemoveAccount;

  /// Selects one item.
  final ValueChanged<SaleItemDraft> onTapItem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _SplitPanelFrame(
      panelKey: ValueKey('split-account-${account.id}'),
      header: Row(
        children: [
          Expanded(
            child: SplitAccountNameInput(
              controller: account.controller,
              label: l10n.accountNameField,
              placeholder: account.placeholder,
            ),
          ),
          IconButton(
            key: ValueKey('split-remove-${account.id}'),
            tooltip: l10n.splitRemoveAccountAction,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: canRemove ? onRemoveAccount : null,
          ),
        ],
      ),
      compact: compact,
      items: items,
      panelWidth: panelWidth,
      selectedItemIds: selectedItemIds,
      onAccept: onAccept,
      onPanelTap: onPanelTap,
      onTapItem: onTapItem,
    );
  }
}

class _SplitPanelFrame extends StatelessWidget {
  const _SplitPanelFrame({
    required this.header,
    required this.items,
    required this.panelWidth,
    required this.selectedItemIds,
    required this.onAccept,
    required this.onTapItem,
    required this.panelKey,
    this.compact = false,
    this.onPanelTap,
  });

  final bool compact;
  final Key panelKey;
  final Widget header;
  final List<SaleItemDraft> items;
  final double panelWidth;
  final Set<String> selectedItemIds;
  final ValueChanged<SaleItemDraft> onAccept;
  final ValueChanged<SaleItemDraft> onTapItem;
  final VoidCallback? onPanelTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final padding = compact ? 8.0 : 12.0;
    final headerSpacing = compact ? 8.0 : 12.0;
    final rowSpacing = compact ? 4.0 : 6.0;

    return SizedBox(
      key: panelKey,
      width: panelWidth,
      child: DragTarget<SaleItemDraft>(
        onAcceptWithDetails: (details) => onAccept(details.data),
        builder: (context, candidateItems, rejectedItems) {
          final highlighted = candidateItems.isNotEmpty;
          return Material(
            color: highlighted
                ? colorScheme.primaryContainer
                : colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onPanelTap,
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    SizedBox(height: headerSpacing),
                    const _SplitHeaderRow(),
                    SizedBox(height: rowSpacing),
                    Expanded(
                      child: ListView.separated(
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return SplitAccountItemRow(
                            key: ValueKey('split-item-${item.id}'),
                            item: item,
                            selected: selectedItemIds.contains(item.id),
                            onTap: () => onTapItem(item),
                          );
                        },
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(height: rowSpacing),
                      ),
                    ),
                    const Divider(height: 16),
                    SplitAccountTotal(items: items),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SplitHeaderRow extends StatelessWidget {
  const _SplitHeaderRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(flex: 5, child: AppText(l10n.posDescriptionColumn)),
        Expanded(flex: 2, child: AppText(l10n.posQuantityColumn)),
        Expanded(
          flex: 3,
          child: AppText(l10n.posAmountColumn, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
