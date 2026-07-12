import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_searchable_list_section.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_settings.dart';
import 'package:smoo_control/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:smoo_control/features/sync/presentation/bloc/sync_event.dart';
import 'package:smoo_control/features/sync/presentation/bloc/sync_state.dart';
import 'package:smoo_control/features/sync/presentation/widgets/sync_queue_tile.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'sync_settings_panel.dart';

/// Local synchronization queue page.
class SyncPage extends StatelessWidget {
  /// Creates the sync page.
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) =>
          serviceLocator<SyncBloc>()..add(const SyncQueueRequested()),
      child: AppPageScaffold(
        title: l10n.moduleSync,
        body: BlocConsumer<SyncBloc, SyncState>(
          listener: (context, state) {
            if (state case SyncLoaded(settingsSaved: true)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Configuracion de sincronizacion guardada.'),
                ),
              );
            }
          },
          builder: (context, state) {
            return switch (state) {
              SyncInitial() || SyncLoading() => const AppLoadingPage(),
              SyncFailure(:final failure) => AppEmptyState(
                icon: Icons.sync_problem_outlined,
                message: failure.message,
                title: l10n.moduleSync,
              ),
              SyncLoaded() => _SyncContent(state: state),
            };
          },
        ),
      ),
    );
  }
}

class _SyncContent extends StatelessWidget {
  const _SyncContent({required this.state});

  final SyncLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _SyncSettingsPanel(settings: state.settings),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              AppButton(
                icon: Icons.sync,
                label: l10n.syncNowAction,
                onPressed: state.items.isEmpty
                    ? null
                    : () => context.read<SyncBloc>().add(
                        const SyncProcessRequested(),
                      ),
              ),
              AppText(
                'Pendientes: ${state.items.length}',
                variant: AppTextVariant.label,
              ),
              const AppText(
                'Los enviados correctamente no quedan listados como '
                'pendientes.',
                maxLines: 2,
                variant: AppTextVariant.label,
              ),
            ],
          ),
        ),
        if (state.lastSummary != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AppText(
              l10n.syncSummary(
                state.lastSummary!.processed,
                state.lastSummary!.succeeded,
                state.lastSummary!.failed,
              ),
            ),
          ),
        Expanded(
          child: state.items.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: Icons.cloud_done_outlined,
                    message: l10n.emptySyncMessage,
                    title: l10n.emptySyncTitle,
                  ),
                )
              : AppSearchableListSection(
                  emptyMessage: l10n.emptySearchMessage,
                  emptyTitle: l10n.emptySearchTitle,
                  items: state.items,
                  searchLabel: l10n.searchField,
                  searchTextForItem: (item) => [
                    item.entityType,
                    item.operation.name,
                    item.status.name,
                    item.lastError ?? '',
                  ].join(' '),
                  itemBuilder: (context, item) => SyncQueueTile(item: item),
                ),
        ),
      ],
    );
  }
}
