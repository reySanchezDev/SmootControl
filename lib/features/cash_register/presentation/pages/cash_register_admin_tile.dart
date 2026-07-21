part of 'cash_register_admin_page.dart';

class _CashRegisterAdminTile extends StatelessWidget {
  const _CashRegisterAdminTile({
    required this.dateFormat,
    required this.onDelete,
    required this.onEdit,
    required this.record,
  });

  final DateFormat dateFormat;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final CashRegisterAdminRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final statusLabel = record.status == 'closed'
        ? l10n.cashRegisterAdminClosed
        : l10n.cashRegisterAdminOpened;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.point_of_sale_outlined, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    '${dateFormat.format(record.businessDate)} | $statusLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    variant: AppTextVariant.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _AmountRow(
              label: l10n.openingCashField,
              value: MoneyFormatter.format(record.openingCashInCents),
            ),
            _AmountRow(
              label: l10n.closingCashField,
              value: record.physicalClosingCashInCents == null
                  ? '-'
                  : MoneyFormatter.format(record.physicalClosingCashInCents!),
            ),
            _AmountRow(
              label: l10n.localUserLabel,
              value: record.cashierName ?? record.cashierId,
            ),
            _AmountRow(
              label: 'Dispositivo',
              value: record.deviceName ?? 'Sin dispositivo',
            ),
            _AmountRow(
              label: 'Apertura',
              value:
                  '${dateFormat.format(record.openedAt)} '
                  '${record.openedAt.hour.toString().padLeft(2, '0')}:'
                  '${record.openedAt.minute.toString().padLeft(2, '0')}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  icon: Icons.edit_outlined,
                  label: l10n.editAction,
                  onPressed: onEdit,
                  primary: false,
                ),
                AppButton(
                  icon: Icons.delete_outline,
                  label: l10n.deleteAction,
                  onPressed: onDelete,
                  primary: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: AppText(label, maxLines: 1)),
          const SizedBox(width: 12),
          Flexible(
            child: AppText(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditCashRegisterDialog extends StatefulWidget {
  const _EditCashRegisterDialog({required this.record});

  final CashRegisterAdminRecord record;

  @override
  State<_EditCashRegisterDialog> createState() =>
      _EditCashRegisterDialogState();
}

class _EditCashRegisterDialogState extends State<_EditCashRegisterDialog> {
  late final TextEditingController _openingController;
  late final TextEditingController _closingController;
  late String _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openingController = TextEditingController(
      text: (widget.record.openingCashInCents / 100).toStringAsFixed(2),
    );
    _closingController = TextEditingController(
      text: widget.record.physicalClosingCashInCents == null
          ? ''
          : (widget.record.physicalClosingCashInCents! / 100).toStringAsFixed(
              2,
            ),
    );
    _status = widget.record.status;
  }

  @override
  void dispose() {
    _openingController.dispose();
    _closingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: AppText(l10n.cashRegisterAdminEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInput(
              controller: _openingController,
              keyboardType: TextInputType.number,
              label: l10n.openingCashField,
            ),
            const SizedBox(height: 12),
            AppInput(
              controller: _closingController,
              keyboardType: TextInputType.number,
              label: l10n.closingCashField,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'open',
                  label: AppText(l10n.cashRegisterAdminOpened),
                ),
                ButtonSegment(
                  value: 'closed',
                  label: AppText(l10n.cashRegisterAdminClosed),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (value) {
                setState(() => _status = value.first);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              AppText(_error!, maxLines: 2),
            ],
          ],
        ),
      ),
      actions: [
        AppButton(
          label: l10n.cancelAction,
          onPressed: () => Navigator.of(context).pop(),
          primary: false,
        ),
        AppButton(label: l10n.saveAction, onPressed: _submit),
      ],
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final opening = MoneyFormatter.parseToCents(_openingController.text);
    final closing = _closingController.text.trim().isEmpty
        ? null
        : MoneyFormatter.parseToCents(_closingController.text);
    if (opening == null ||
        (_closingController.text.isNotEmpty && closing == null)) {
      setState(() => _error = l10n.numericFieldError);
      return;
    }
    Navigator.of(context).pop(
      widget.record.copyWith(
        openingCashInCents: opening,
        physicalClosingCashInCents: closing,
        status: _status,
      ),
    );
  }
}
