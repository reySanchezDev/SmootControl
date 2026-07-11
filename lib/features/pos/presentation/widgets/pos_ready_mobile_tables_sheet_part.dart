part of 'pos_ready_view.dart';

class _MobileTablesSheet extends StatelessWidget {
  const _MobileTablesSheet({
    required this.onClose,
    required this.state,
  });

  final VoidCallback onClose;
  final PosReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height = MediaQuery.sizeOf(context).height * .72;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 2, 64, 0),
                    child: Text(
                      l10n.moduleTables,
                      style:
                          Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: PosTablesBand(
                      onEntrySelected: onClose,
                      state: state,
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 2,
                bottom: 10,
                child: _FloatingSheetCloseButton(onPressed: onClose),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileTablesButton extends StatelessWidget {
  const _MobileTablesButton({
    required this.onPressed,
    required this.tooltip,
  });

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final foreground = enabled
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: .38);
    return Tooltip(
      message: tooltip,
      child: Material(
        key: const ValueKey('pos-mobile-tables-button'),
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: .42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            child: Icon(
              Icons.table_restaurant_outlined,
              color: foreground,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingSheetCloseButton extends StatelessWidget {
  const _FloatingSheetCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      elevation: 6,
      shadowColor: colorScheme.error.withValues(alpha: .24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: SizedBox(
          height: 56,
          width: 56,
          child: Icon(Icons.close, color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

class _MobileCatalogModeButton extends StatelessWidget {
  const _MobileCatalogModeButton({
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final background = active ? AppPalette.primaryDark : AppPalette.accentSoft;
    final foreground = active ? AppPalette.surface : AppPalette.textPrimary;
    final border = active
        ? AppPalette.primaryDark
        : AppPalette.accent.withValues(alpha: .42);
    final icon = active ? Icons.shopping_cart : Icons.receipt_long_outlined;
    return Tooltip(
      message: active ? 'Ver orden' : 'Ver productos',
      child: Material(
        key: const ValueKey('pos-mobile-cart-mode-button'),
        clipBehavior: Clip.antiAlias,
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            child: Icon(
              icon,
              color: foreground,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileTableSelectionLabel extends StatelessWidget {
  const _MobileTableSelectionLabel({
    required this.primaryColor,
    required this.secondaryColor,
    required this.selectedLabel,
    required this.totalLabel,
    super.key,
  });

  final Color primaryColor;
  final Color secondaryColor;
  final String? selectedLabel;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          selectedLabel ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: primaryColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          totalLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: secondaryColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MobileTableOption {
  const _MobileTableOption({
    required this.id,
    required this.isOccupied,
    required this.label,
  });

  final String id;
  final bool isOccupied;
  final String label;
}
