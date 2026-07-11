part of 'dashboard_page.dart';

class _DashboardAccess {
  const _DashboardAccess({
    this.isAdmin = false,
    this.permissionCodes = const {},
  });

  final bool isAdmin;
  final Set<String> permissionCodes;

  bool canOpen(String route) {
    if (isAdmin) return true;

    final permissions = RouteAccess.anyPermissionsFor(route);
    if (permissions.isEmpty) return true;

    return permissions.any(permissionCodes.contains);
  }
}

class _ModuleDefinition {
  const _ModuleDefinition({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

class _DashboardSection {
  const _DashboardSection({
    required this.title,
    required this.modules,
  });

  final String title;
  final List<_ModuleDefinition> modules;
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({
    required this.cards,
    required this.size,
  });

  final List<Widget> cards;
  final ResponsiveSize size;

  @override
  Widget build(BuildContext context) {
    final columns = switch (size) {
      ResponsiveSize.mobile => 2,
      ResponsiveSize.tablet => 3,
      ResponsiveSize.desktop => 4,
    };

    return GridView.count(
      childAspectRatio: size == ResponsiveSize.mobile ? 2.55 : 2.9,
      crossAxisCount: columns,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: cards,
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).pushNamed(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  variant: AppTextVariant.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
