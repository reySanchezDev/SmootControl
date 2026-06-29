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

class _SyncSettingsPanel extends StatefulWidget {
  const _SyncSettingsPanel({required this.settings});

  final SyncSettings settings;

  @override
  State<_SyncSettingsPanel> createState() => _SyncSettingsPanelState();
}

class _SyncSettingsPanelState extends State<_SyncSettingsPanel> {
  static const _intervalOptions = [5, 10, 15, 30, 60];

  late bool _autoSyncEnabled;
  late bool _syncOnStartup;
  late bool _syncOnSave;
  late int _intervalMinutes;

  @override
  void initState() {
    super.initState();
    _apply(widget.settings);
  }

  @override
  void didUpdateWidget(covariant _SyncSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _apply(widget.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_sync_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: AppText(
                    'Configuracion automatica',
                    variant: AppTextVariant.titleMedium,
                  ),
                ),
                AppButton(
                  icon: Icons.save_outlined,
                  label: 'Guardar',
                  onPressed: _save,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilterChip(
                  selected: _autoSyncEnabled,
                  avatar: const Icon(Icons.schedule_outlined),
                  label: const Text('Automatico'),
                  onSelected: (value) =>
                      setState(() => _autoSyncEnabled = value),
                ),
                FilterChip(
                  selected: _syncOnStartup,
                  avatar: const Icon(Icons.rocket_launch_outlined),
                  label: const Text('Al iniciar'),
                  onSelected: (value) => setState(() => _syncOnStartup = value),
                ),
                FilterChip(
                  selected: _syncOnSave,
                  avatar: const Icon(Icons.save_as_outlined),
                  label: const Text('Al guardar'),
                  onSelected: (value) => setState(() => _syncOnSave = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const AppText('Frecuencia', variant: AppTextVariant.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in _intervalOptions)
                  ChoiceChip(
                    selected: _intervalMinutes == minutes,
                    label: Text('$minutes min'),
                    onSelected: (_) =>
                        setState(() => _intervalMinutes = minutes),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _apply(SyncSettings settings) {
    _autoSyncEnabled = settings.autoSyncEnabled;
    _syncOnStartup = settings.syncOnStartup;
    _syncOnSave = settings.syncOnSave;
    _intervalMinutes = _intervalOptions.contains(settings.intervalMinutes)
        ? settings.intervalMinutes
        : 5;
  }

  void _save() {
    context.read<SyncBloc>().add(
      SyncSettingsSaved(
        SyncSettings(
          autoSyncEnabled: _autoSyncEnabled,
          intervalMinutes: _intervalMinutes,
          syncOnStartup: _syncOnStartup,
          syncOnSave: _syncOnSave,
        ),
      ),
    );
  }
}
