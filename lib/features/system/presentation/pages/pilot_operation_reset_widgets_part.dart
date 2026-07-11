part of 'pilot_operation_reset_page.dart';

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: AppText(
                  'Limpiezas controladas de preproduccion. Cada accion borra '
                  'primero los datos locales de este movil para evitar '
                  'reenvios, y luego limpia Supabase.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.children,
    required this.title,
  });

  final List<Widget> children;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: AppText(title, variant: AppTextVariant.titleMedium),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final columns = constraints.maxWidth >= 720 ? 2 : 1;
              final itemWidth =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final child in children)
                    SizedBox(width: itemWidth, child: child),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CleanupCard extends StatelessWidget {
  const _CleanupCard({
    required this.busy,
    required this.confirmation,
    required this.description,
    required this.icon,
    required this.onRun,
    required this.title,
    this.destructive = false,
  });

  final bool busy;
  final String confirmation;
  final bool destructive;
  final String description;
  final IconData icon;
  final VoidCallback onRun;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = destructive ? colorScheme.error : colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    variant: AppTextVariant.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppText(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              variant: AppTextVariant.label,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: AppText(
                      confirmation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      variant: AppTextVariant.label,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: destructive
                      ? FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                        )
                      : FilledButton.styleFrom(
                          minimumSize: const Size(112, 44),
                        ),
                  onPressed: busy ? null : onRun,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
