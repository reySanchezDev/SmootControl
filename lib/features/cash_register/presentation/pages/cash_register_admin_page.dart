import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/cash_register/data/services/supabase_cash_register_admin_service.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_admin_record.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'cash_register_admin_tile.dart';

/// Administrative screen for remote cash register sessions.
class CashRegisterAdminPage extends StatefulWidget {
  /// Creates the remote cash register admin page.
  const CashRegisterAdminPage({super.key});

  @override
  State<CashRegisterAdminPage> createState() => _CashRegisterAdminPageState();
}

class _CashRegisterAdminPageState extends State<CashRegisterAdminPage> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final SupabaseCashRegisterAdminService _service =
      serviceLocator<SupabaseCashRegisterAdminService>();
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _to = DateTime.now();
  List<CashRegisterAdminRecord> _records = <CashRegisterAdminRecord>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPageScaffold(
      title: l10n.cashRegisterAdminTitle,
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DateFilter(
            from: _from,
            to: _to,
            onFrom: () => _pickDate(isFrom: true),
            onTo: () => _pickDate(isFrom: false),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            AppEmptyState(
              icon: Icons.error_outline,
              message: _error!,
              title: l10n.cashRegisterAdminTitle,
            )
          else if (_records.isEmpty)
            AppEmptyState(
              icon: Icons.point_of_sale_outlined,
              message: l10n.cashRegisterAdminEmpty,
              title: l10n.moduleCashRegister,
            )
          else
            for (final record in _records) ...[
              _CashRegisterAdminTile(
                dateFormat: _dateFormat,
                onDelete: () => _delete(record),
                onEdit: () => _edit(record),
                record: record,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initialDate = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      initialDate: initialDate,
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.load(from: _from, to: _to);
    if (!mounted) return;
    switch (result) {
      case AppSuccess(:final value):
        setState(() {
          _records = value;
          _loading = false;
        });
      case AppFailureResult(:final error):
        setState(() {
          _error = error.message;
          _loading = false;
        });
    }
  }

  Future<void> _edit(CashRegisterAdminRecord record) async {
    final edited = await showDialog<CashRegisterAdminRecord>(
      context: context,
      builder: (_) => _EditCashRegisterDialog(record: record),
    );
    if (edited == null || !mounted) return;
    final result = await _service.update(edited);
    if (!mounted) return;
    await _handleMutationResult(
      result,
      AppLocalizations.of(context).cashRegisterAdminSaved,
    );
  }

  Future<void> _delete(CashRegisterAdminRecord record) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText(l10n.cashRegisterAdminDelete),
        content: AppText(l10n.cashRegisterAdminDeleteConfirm, maxLines: 5),
        actions: [
          AppButton(
            label: l10n.cancelAction,
            onPressed: () => Navigator.of(context).pop(false),
            primary: false,
          ),
          AppButton(
            label: l10n.deleteAction,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await _service.delete(record.id);
    if (!mounted) return;
    await _handleMutationResult(result, l10n.cashRegisterAdminDeleted);
  }

  Future<void> _handleMutationResult<T>(
    AppResult<T> result,
    String successMessage,
  ) async {
    switch (result) {
      case AppSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(successMessage)),
        );
        await _load();
      case AppFailureResult(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(error.message, maxLines: 3)),
        );
    }
  }
}

class _DateFilter extends StatelessWidget {
  const _DateFilter({
    required this.from,
    required this.onFrom,
    required this.onTo,
    required this.to,
  });

  final DateTime from;
  final DateTime to;
  final VoidCallback onFrom;
  final VoidCallback onTo;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Wrap(
      runSpacing: 8,
      spacing: 8,
      children: [
        AppButton(
          icon: Icons.calendar_month_outlined,
          label: dateFormat.format(from),
          onPressed: onFrom,
          primary: false,
        ),
        AppButton(
          icon: Icons.event_available_outlined,
          label: dateFormat.format(to),
          onPressed: onTo,
          primary: false,
        ),
      ],
    );
  }
}
