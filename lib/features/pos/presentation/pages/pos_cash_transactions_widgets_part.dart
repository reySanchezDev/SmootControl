part of 'pos_cash_transactions_page.dart';

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
    this.text, {
    required this.flex,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final int flex;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(
    this.text, {
    required this.flex,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final int flex;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: AppText(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      ),
    );
  }
}

class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({required this.status});

  final SaleSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final style = switch (status) {
      SaleSyncStatus.synced => (
        icon: Icons.cloud_done_outlined,
        label: l10n.syncStatusSynced,
        color: colorScheme.primary,
      ),
      SaleSyncStatus.syncing => (
        icon: Icons.cloud_sync_outlined,
        label: l10n.syncStatusSyncing,
        color: colorScheme.tertiary,
      ),
      SaleSyncStatus.error => (
        icon: Icons.cloud_off_outlined,
        label: l10n.syncStatusError,
        color: colorScheme.error,
      ),
      SaleSyncStatus.pending => (
        icon: Icons.cloud_queue_outlined,
        label: l10n.syncStatusPending,
        color: colorScheme.onSurfaceVariant,
      ),
    };

    return Chip(
      avatar: Icon(style.icon, size: 16, color: style.color),
      label: Text(style.label),
      side: BorderSide(color: style.color),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TransactionsData {
  const _TransactionsData({
    required this.sales,
    required this.paymentMethods,
    required this.canRunManualSync,
  }) : failure = null;

  const _TransactionsData.failure(String message)
    : sales = const [],
      paymentMethods = const {},
      canRunManualSync = false,
      failure = message;

  final List<Sale> sales;
  final Map<String, String> paymentMethods;
  final bool canRunManualSync;
  final String? failure;
}
