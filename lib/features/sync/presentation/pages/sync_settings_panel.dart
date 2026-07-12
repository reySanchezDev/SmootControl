part of 'sync_page.dart';

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
              runSpacing: 12,
              children: [
                _SyncToggleTile(
                  icon: Icons.schedule_outlined,
                  label: 'Automatico',
                  value: _autoSyncEnabled,
                  onChanged: (value) =>
                      setState(() => _autoSyncEnabled = value),
                ),
                _SyncToggleTile(
                  icon: Icons.rocket_launch_outlined,
                  label: 'Al iniciar',
                  value: _syncOnStartup,
                  onChanged: (value) => setState(() => _syncOnStartup = value),
                ),
                _SyncToggleTile(
                  icon: Icons.save_as_outlined,
                  label: 'Al guardar',
                  value: _syncOnSave,
                  onChanged: (value) => setState(() => _syncOnSave = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppText(
              'Frecuencia del temporizador',
              variant: AppTextVariant.label,
              style: TextStyle(
                color: _autoSyncEnabled
                    ? null
                    : Theme.of(context).disabledColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in _intervalOptions)
                  ChoiceChip(
                    selected: _intervalMinutes == minutes,
                    label: Text('$minutes min'),
                    onSelected: _autoSyncEnabled
                        ? (_) => setState(() => _intervalMinutes = minutes)
                        : null,
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

class _SyncToggleTile extends StatelessWidget {
  const _SyncToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = value ? colorScheme.primary : colorScheme.onSurface;

    return SizedBox(
      width: 260,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: value ? colorScheme.primaryContainer : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? colorScheme.primary : Theme.of(context).dividerColor,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(label, variant: AppTextVariant.label),
                    AppText(
                      value ? 'Activado' : 'Desactivado',
                      variant: AppTextVariant.label,
                      style: TextStyle(color: statusColor),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
