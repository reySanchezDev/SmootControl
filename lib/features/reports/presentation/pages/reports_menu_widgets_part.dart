part of 'reports_page.dart';

/// A named category in the dedicated reporting module.
class _ReportsSection extends StatelessWidget {
  const _ReportsSection({
    required this.children,
    required this.title,
  });

  final List<Widget> children;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: AppText(title, variant: AppTextVariant.titleMedium),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i != 0) const Divider(height: 1),
                    children[i],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One explicit report option, not an oversized dashboard card.
class _ReportOptionCard extends StatelessWidget {
  const _ReportOptionCard({
    required this.icon,
    required this.routeName,
    required this.subtitle,
    required this.title,
  });

  final IconData icon;
  final String routeName;
  final String subtitle;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: AppText(title),
      subtitle: AppText(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        variant: AppTextVariant.label,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pushNamed(routeName),
    );
  }
}
