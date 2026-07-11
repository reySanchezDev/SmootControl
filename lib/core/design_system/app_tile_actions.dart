import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// One action shown from an administrative list tile.
final class AppTileAction {
  /// Creates a tile action.
  const AppTileAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.enabled = true,
  });

  /// Action icon.
  final IconData icon;

  /// User-facing action label.
  final String label;

  /// Action callback.
  final VoidCallback onPressed;

  /// Optional icon color.
  final Color? color;

  /// Whether the action is enabled.
  final bool enabled;
}

/// Responsive action cluster for list rows.
///
/// Use this instead of placing several [IconButton]s directly in `trailing`.
/// On compact mobile widths, inline actions can starve the title/subtitle and
/// make words render vertically. This widget collapses actions into a popup.
class AppTileActions extends StatelessWidget {
  /// Creates responsive tile actions.
  const AppTileActions({
    required this.actions,
    this.compact = false,
    this.inlineLeading,
    super.key,
  });

  /// Whether actions should be collapsed into a menu.
  final bool compact;

  /// Optional small label shown before inline action buttons on wide screens.
  final Widget? inlineLeading;

  /// Actions available for the row.
  final List<AppTileAction> actions;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return PopupMenuButton<int>(
        icon: const Icon(Icons.more_vert),
        itemBuilder: (context) => [
          for (var index = 0; index < actions.length; index++)
            PopupMenuItem(
              enabled: actions[index].enabled,
              value: index,
              child: _PopupActionLabel(action: actions[index]),
            ),
        ],
        onSelected: (index) => actions[index].onPressed(),
        tooltip: AppLocalizations.of(context).moreOptionsAction,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?inlineLeading,
        for (final action in actions)
          IconButton(
            color: action.color,
            icon: Icon(action.icon),
            onPressed: action.enabled ? action.onPressed : null,
            tooltip: action.label,
          ),
      ],
    );
  }
}

class _PopupActionLabel extends StatelessWidget {
  const _PopupActionLabel({required this.action});

  final AppTileAction action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          action.icon,
          color: action.enabled
              ? action.color
              : Theme.of(context).disabledColor,
        ),
        const SizedBox(width: 12),
        Expanded(child: AppText(action.label)),
      ],
    );
  }
}
