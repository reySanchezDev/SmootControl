import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
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
  final SupabaseAdminRepository _repository =
      serviceLocator<SupabaseAdminRepository>();
  late DateTime _month;
  late Future<AppResult<List<ExchangeRate>>> _future;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPageScaffold(
      title: l10n.moduleExchangeRates,
      actions: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _previousMonth,
          tooltip: l10n.previousAction,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _nextMonth,
          tooltip: l10n.nextAction,
        ),
      ],
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
        AppText(
          '${l10n.exchangeRateMonthLabel}: ${_month.month}/${_month.year}',
          variant: AppTextVariant.titleMedium,
        ),
        const SizedBox(height: 12),
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

            return Row(
              children: [
                Expanded(child: input),
                const SizedBox(width: 12),
                action,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        for (var day = 1; day <= days; day += 1)
          _RateTile(
            currencyCode: _currencyCode,
            date: DateTime(_month.year, _month.month, day),
            rate: byDay[day],
            onSaved: _saveRate,
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

  void _previousMonth() {
    _month = DateTime(_month.year, _month.month - 1);
    _load();
  }

  void _nextMonth() {
    _month = DateTime(_month.year, _month.month + 1);
    _load();
  }

  Future<void> _applyMonthRate() async {
    final rateInCents = MoneyFormatter.parseToCents(
      _monthlyRateController.text,
    );
    if (rateInCents == null) return;

    await _repository.fillMonth(
      currencyCode: _currencyCode,
      month: _month,
      rateInCents: rateInCents,
    );
    _load();
  }

  Future<void> _saveRate(DateTime date, int rateInCents) async {
    await _repository.saveRate(
      ExchangeRate(
        currencyCode: _currencyCode,
        businessDate: date,
        rateInCents: rateInCents,
      ),
    );
    _load();
  }
}
