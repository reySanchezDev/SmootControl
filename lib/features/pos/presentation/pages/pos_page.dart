import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/utils/business_date_formatter.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/cash_register/presentation/widgets/close_cash_register_dialog.dart';
import 'package:smoo_control/features/cash_register/presentation/widgets/open_cash_register_dialog.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_ready_view.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Responsive POS page.
class PosPage extends StatelessWidget {
  /// Creates the POS page.
  const PosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) => serviceLocator<PosBloc>()..add(const PosStarted()),
      child: AppPageScaffold(
        showAppBar: false,
        title: l10n.primaryAction,
        body: BlocConsumer<PosBloc, PosState>(
          listener: (context, state) {
            if (state is PosFailure) {
              unawaited(
                showAppMessageDialog(
                  context: context,
                  message: state.failure.message,
                  title: l10n.primaryAction,
                ),
              );
            }
          },
          builder: (context, state) {
            return switch (state) {
              PosInitial() || PosLoading() => const AppLoadingPage(),
              PosCashRegisterRequired() => const _OpenCashFromPosView(),
              PosStaleCashRegisterRequired(:final session) =>
                _StaleCashFromPosView(session: session),
              PosFailure(:final failure) => AppEmptyState(
                icon: Icons.error_outline,
                message: failure.message,
                title: l10n.primaryAction,
              ),
              PosReady() => PosReadyView(state: state),
            };
          },
        ),
      ),
    );
  }
}

class _StaleCashFromPosView extends StatelessWidget {
  const _StaleCashFromPosView({required this.session});

  final CashRegisterSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final businessDate = BusinessDateFormatter.format(session.businessDate);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 56),
            const SizedBox(height: 16),
            AppText(
              l10n.posStaleCashRegisterRequiredTitle,
              variant: AppTextVariant.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppText(
              l10n.posStaleCashRegisterRequiredMessage(businessDate),
              textAlign: TextAlign.center,
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 260,
              height: 64,
              child: FilledButton.icon(
                onPressed: () => _closeCashRegister(context),
                icon: const Icon(Icons.lock_outline),
                label: Text(l10n.posCloseCashRegisterAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _closeCashRegister(BuildContext context) async {
    final draft = await showDialog<CloseCashRegisterDraft>(
      context: context,
      builder: (_) => const CloseCashRegisterDialog(),
    );

    if (draft != null && context.mounted) {
      context.read<PosBloc>().add(
        PosCashRegisterClosed(
          physicalClosingCashInCents: draft.physicalClosingCashInCents,
        ),
      );
    }
  }
}

class _OpenCashFromPosView extends StatelessWidget {
  const _OpenCashFromPosView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.point_of_sale_outlined, size: 56),
            const SizedBox(height: 16),
            AppText(
              l10n.posCashRegisterRequiredTitle,
              variant: AppTextVariant.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppText(
              l10n.posCashRegisterRequiredMessage,
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 260,
              height: 64,
              child: FilledButton.icon(
                onPressed: () => _openCashRegister(context),
                icon: const Icon(Icons.lock_open_outlined),
                label: Text(l10n.posOpenCashRegisterAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCashRegister(BuildContext context) async {
    final session = await showDialog<CashRegisterSession>(
      context: context,
      builder: (_) => const OpenCashRegisterDialog(),
    );

    if (session != null && context.mounted) {
      context.read<PosBloc>().add(PosCashRegisterOpened(session));
    }
  }
}
