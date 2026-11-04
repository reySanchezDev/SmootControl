import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/backoffice_form_standards.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/exchange_rates/domain/entities/exchange_rate.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'exchange_rate_tile.dart';

/// Exchange rate management page for the current month.
class ExchangeRatesPage extends StatefulWidget {
  /// Creates the exchange rates page.
  const ExchangeRatesPage({super.key});

  @override
  State<ExchangeRatesPage> createState() => _ExchangeRatesPageState();
}

class _ExchangeRatesPageState extends State<ExchangeRatesPage> {
  static const _currencyCode = 'USD';

  final _monthlyRateController = TextEditingController();
  final List<FocusNode> _dailyRateFocusNodes = List.generate(
    31,
    (index) => FocusNode(debugLabel: 'Tasa diaria ${index + 1}'),
  );
  final SupabaseAdminRepository _repository =
      serviceLocator<SupabaseAdminRepository>();
  late DateTime _month;
  late Future<AppResult<List<ExchangeRate>>> _future;
  final Set<Future<AppResult<ExchangeRate>>> _pendingDailySaves = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  @override
  void dispose() {
    _monthlyRateController.dispose();
    for (final node in _dailyRateFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPageScaffold(
      title: l10n.moduleExchangeRates,
      body: FutureBuilder<AppResult<List<ExchangeRate>>>(
        future: _future,
        builder: (context, snapshot) {
          final result = snapshot.data;
          if (result == null) return const AppLoadingPage();

          return result.when(
            success: _body,
            failure: (failure) => AppEmptyState(
              icon: Icons.error_outline,
              message: failure.message,
              title: l10n.moduleExchangeRates,
            ),
          );
        },
      ),
    );
  }

  Widget _body(List<ExchangeRate> rates) {
    final l10n = AppLocalizations.of(context);
    final byDay = {
      for (final rate in rates) rate.businessDate.day: rate,
    };
    final days = DateTime(_month.year, _month.month + 1, 0).day;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: BackofficeFormStandards.filterGap,
          runSpacing: BackofficeFormStandards.filterGap,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.chevron_left),
              label: Text(l10n.previousAction),
              onPressed: _previousMonth,
            ),
            AppText(
              '${l10n.exchangeRateMonthLabel}: ${_month.month}/${_month.year}',
              variant: AppTextVariant.titleMedium,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.chevron_right),
              label: Text(l10n.nextAction),
              onPressed: _nextMonth,
            ),
          ],
        ),
        const SizedBox(height: BackofficeFormStandards.sectionGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;
            final input = TextField(
              controller: _monthlyRateController,
              decoration: InputDecoration(
                labelText: l10n.exchangeRateMonthlyField,
              ),
              keyboardType: TextInputType.number,
            );
            final action = AppButton(
              label: l10n.exchangeRateApplyMonthAction,
              onPressed: _applyMonthRate,
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  input,
                  const SizedBox(height: 12),
                  action,
                ],
              );
            }

            return Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: BackofficeFormStandards.filterGap,
                runSpacing: BackofficeFormStandards.filterGap,
                children: [
                  SizedBox(
                    width: BackofficeFormStandards.filterWidth,
                    child: input,
                  ),
                  action,
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Las tasas diarias se guardan automáticamente al salir del campo.',
        ),
        const SizedBox(height: 8),
        // Keep all 28–31 editors mounted so keyboard focus can reach
        // the next day even when it starts outside the viewport.
        Column(
          children: [
            for (var day = 1; day <= days; day += 1)
              ExchangeRateTile(
                key: ValueKey(DateTime(_month.year, _month.month, day)),
                currencyCode: _currencyCode,
                date: DateTime(_month.year, _month.month, day),
                rate: byDay[day],
                onSaved: _saveRate,
                focusNode: _dailyRateFocusNodes[day - 1],
                previousFocusNode: day > 1
                    ? _dailyRateFocusNodes[day - 2]
                    : null,
                nextFocusNode: day < days ? _dailyRateFocusNodes[day] : null,
              ),
          ],
        ),
      ],
    );
  }

  void _load() {
    setState(() {
      _future = _loadRates();
    });
  }

  Future<AppResult<List<ExchangeRate>>> _loadRates() async {
    return _repository.getRatesForMonth(
      currencyCode: _currencyCode,
      month: _month,
    );
  }

  Future<void> _waitForDailySaves() async {
    while (_pendingDailySaves.isNotEmpty) {
      await Future.wait(_pendingDailySaves.toList());
    }
  }

  Future<void> _previousMonth() => _changeMonth(-1);

  Future<void> _nextMonth() => _changeMonth(1);

  Future<void> _changeMonth(int offset) async {
    await _waitForDailySaves();
    if (!mounted) return;
    _month = DateTime(_month.year, _month.month + offset);
    _load();
  }

  Future<void> _applyMonthRate() async {
    final rateInCents = MoneyFormatter.parseToCents(
      _monthlyRateController.text,
    );
    if (rateInCents == null || rateInCents <= 0) return;

    await _waitForDailySaves();
    if (!mounted) return;
    final result = await _repository.fillMonth(
      currencyCode: _currencyCode,
      month: _month,
      rateInCents: rateInCents,
    );
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        _load();
      case AppFailureResult(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
    }
  }

  Future<AppResult<ExchangeRate>> _saveRate(
    DateTime date,
    int rateInCents,
  ) async {
    final operation = _repository.saveRate(
      ExchangeRate(
        currencyCode: _currencyCode,
        businessDate: date,
        rateInCents: rateInCents,
      ),
    );
    _pendingDailySaves.add(operation);
    try {
      return await operation;
    } finally {
      _pendingDailySaves.remove(operation);
    }
  }
}
