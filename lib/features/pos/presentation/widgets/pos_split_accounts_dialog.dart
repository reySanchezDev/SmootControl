import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_danger_confirmation.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_split_accounts_workspace.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item_draft.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Full split-account workspace for assigning table items to named accounts.
class PosSplitAccountsDialog extends StatefulWidget {
  /// Creates the split accounts workspace.
  const PosSplitAccountsDialog({required this.state, super.key});

  /// Current POS ready state.
  final PosReady state;

  @override
  State<PosSplitAccountsDialog> createState() => _PosSplitAccountsDialogState();
}

class _PosSplitAccountsDialogState extends State<PosSplitAccountsDialog> {
  final _assignments = <String, String>{};
  final _accounts = <SplitAccountEditor>[];
  final _selectedItemIds = <String>{};
  var _nextAccountNumber = 1;

  @override
  void initState() {
    super.initState();
    if (widget.state.splitAccounts.isEmpty) {
      _addAccount();
      _addAccount();
    } else {
      for (final account in widget.state.splitAccounts) {
        _accounts.add(
          SplitAccountEditor(
            id: account.id,
            controller: TextEditingController(text: account.name),
            placeholder: account.name,
          ),
        );
        for (final itemId in account.itemIds) {
          _assignments[itemId] = account.id;
        }
      }
      _nextAccountNumber = _accounts.length + 1;
    }
  }

  @override
  void dispose() {
    for (final account in _accounts) {
      account.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = widget.state.splitDraftItems;
    final tableName =
        widget.state.selectedTable?.operationalName ?? l10n.tableField;

    return Dialog.fullscreen(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _SplitDialogLayout.fromWidth(constraints.maxWidth);
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SplitOriginalOrderPanel(
                        title: '$tableName - ${l10n.splitOriginalOrderTitle}',
                        compact: layout.compact,
                        items: _itemsForAccount(null, items),
                        panelWidth: layout.originalPanelWidth,
                        selectedItemIds: _selectedItemIds,
                        onAddAccount: _addAccount,
                        onAccept: (item) => _moveItem(item, null),
                        onCancel: () => Navigator.of(context).pop(),
                        onConfirm: _confirm,
                        onPanelTap: () => _moveSelectedTo(null, items),
                        onTapItem: _toggleItemSelection,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ListView(
                          key: const ValueKey('split-horizontal-list'),
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final account in _accounts) ...[
                              SplitAccountPanel(
                                account: account,
                                canRemove: _accounts.length > 2,
                                compact: layout.compact,
                                items: _itemsForAccount(account.id, items),
                                panelWidth: layout.accountPanelWidth,
                                selectedItemIds: _selectedItemIds,
                                onAccept: (item) {
                                  _moveItem(item, account.id);
                                },
                                onPanelTap: () {
                                  _moveSelectedTo(account.id, items);
                                },
                                onRemoveAccount: () {
                                  unawaited(_confirmRemoveAccount(account));
                                },
                                onTapItem: _toggleItemSelection,
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _moveSelectedTo(String? accountId, List<SaleItemDraft> items) {
    if (_selectedItemIds.isEmpty) return;
    final validIds = items.map((item) => item.id).toSet();
    setState(() {
      for (final itemId in _selectedItemIds) {
        if (!validIds.contains(itemId)) continue;
        if (accountId == null) {
          _assignments.remove(itemId);
        } else {
          _assignments[itemId] = accountId;
        }
      }
      _selectedItemIds.clear();
    });
  }

  void _moveItem(SaleItemDraft item, String? accountId) {
    setState(() {
      if (accountId == null) {
        _assignments.remove(item.id);
      } else {
        _assignments[item.id] = accountId;
      }
      _selectedItemIds.remove(item.id);
    });
  }

  void _toggleItemSelection(SaleItemDraft item) {
    setState(() {
      if (!_selectedItemIds.remove(item.id)) {
        _selectedItemIds.add(item.id);
      }
    });
  }

  List<SaleItemDraft> _itemsForAccount(
    String? accountId,
    List<SaleItemDraft> items,
  ) {
    return items.where((item) => _assignments[item.id] == accountId).toList();
  }

  void _addAccount() {
    setState(() {
      final number = _nextAccountNumber;
      _nextAccountNumber += 1;
      _accounts.add(
        SplitAccountEditor(
          id: 'account-$number',
          controller: TextEditingController(),
          placeholder: 'Cuenta $number',
        ),
      );
    });
  }

  void _removeAccount(String accountId) {
    if (_accounts.length <= 2) return;
    setState(() {
      final index = _accounts.indexWhere((account) => account.id == accountId);
      if (index == -1) return;
      _accounts.removeAt(index).controller.dispose();
      _assignments.removeWhere((_, value) => value == accountId);
      _selectedItemIds.clear();
    });
  }

  Future<void> _confirmRemoveAccount(SplitAccountEditor account) async {
    if (_accounts.length <= 2) return;
    final confirmed = await confirmRemoveSplitAccount(
      context,
      name: _resolvedAccountName(account),
    );
    if (!confirmed || !mounted) return;
    _removeAccount(account.id);
  }

  void _confirm() {
    final tableId = widget.state.selectedTableId;
    if (tableId == null) return;
    if (!_canConfirm(widget.state.splitDraftItems)) {
      unawaited(
        showAppMessageDialog(
          context: context,
          message: AppLocalizations.of(context).splitAccountsPendingError,
          title: AppLocalizations.of(context).splitAccountsAction,
        ),
      );
      return;
    }

    final accounts = [
      for (final account in _accounts)
        AccountSplitDraft(
          id: account.id,
          tableId: tableId,
          name: _resolvedAccountName(account),
          itemIds: [
            for (final entry in _assignments.entries)
              if (entry.value == account.id) entry.key,
          ],
        ),
    ];

    context.read<PosBloc>().add(PosAccountsSplitConfirmed(accounts));
    Navigator.of(context).pop();
  }

  bool _canConfirm(List<SaleItemDraft> items) {
    final everyItemAssigned = items.every((item) {
      return _assignments.containsKey(item.id);
    });
    final everyAccountHasItems = _accounts.every((account) {
      return _assignments.containsValue(account.id);
    });
    return everyItemAssigned && everyAccountHasItems;
  }

  String _resolvedAccountName(SplitAccountEditor account) {
    final typedName = account.controller.text.trim();
    if (typedName.isNotEmpty) return typedName;
    return account.placeholder;
  }
}

final class _SplitDialogLayout {
  const _SplitDialogLayout({
    required this.accountPanelWidth,
    required this.compact,
    required this.originalPanelWidth,
  });

  factory _SplitDialogLayout.fromWidth(double width) {
    final usableWidth = width - 28;
    final targetWidth = ((usableWidth - 16) / 3).clamp(250.0, 390.0);
    final compact = targetWidth < 300;
    return _SplitDialogLayout(
      accountPanelWidth: targetWidth,
      compact: compact,
      originalPanelWidth: targetWidth,
    );
  }

  final double accountPanelWidth;
  final bool compact;
  final double originalPanelWidth;
}
