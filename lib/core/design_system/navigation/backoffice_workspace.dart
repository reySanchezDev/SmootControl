import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/navigation/backoffice_sidebar.dart';

/// Identifies a work tab without conflating separate records of one module.
@immutable
class BackofficeWorkspaceItem {
  /// Creates a workspace destination.
  const BackofficeWorkspaceItem({
    required this.id,
    required this.label,
    required this.route,
    required this.icon,
    this.group = 'General',
    this.closable = true,
  });

  /// Stable identifier used to preserve the tab and page state.
  final String id;

  /// Label displayed in the sidebar and tab strip.
  final String label;

  /// Existing application route represented by this destination.
  final String route;

  /// Icon displayed in the sidebar and tab strip.
  final IconData icon;

  /// Group heading used by the sidebar.
  final String group;

  /// Whether the tab may be closed by the user.
  final bool closable;
}

/// Builder provided by the application routing layer.
///
/// The caller must apply its existing authorization and online-access guards.
typedef BackofficeWorkspacePageBuilder =
    Widget Function(BuildContext context, BackofficeWorkspaceItem item);

/// Desktop workspace foundation, intentionally opt-in until route integration.
///
/// Keeping children in an IndexedStack maintains mounted page state while tabs
/// are switched. Closing a tab disposes its subtree; browser refresh does not
/// persist unsaved form data.
class BackofficeWorkspace extends StatefulWidget {
  /// Creates an isolated, opt-in Backoffice workspace shell.
  const BackofficeWorkspace({
    required this.items,
    required this.pageBuilder,
    this.initialItemId,
    this.onCloseRequested,
    super.key,
  });

  /// Destinations already filtered according to the current user's permissions.
  final List<BackofficeWorkspaceItem> items;

  /// Must return a page protected by the established route access guards.
  final BackofficeWorkspacePageBuilder pageBuilder;

  /// An optional initially selected destination.
  final String? initialItemId;

  /// Optional asynchronous veto, such as a dirty-form confirmation.
  final Future<bool> Function(BackofficeWorkspaceItem item)? onCloseRequested;

  @override
  State<BackofficeWorkspace> createState() => _BackofficeWorkspaceState();
}

class _BackofficeWorkspaceState extends State<BackofficeWorkspace> {
  bool _collapsed = false;
  final List<String> _openIds = <String>[];
  String? _activeId;

  @override
  void initState() {
    super.initState();
    if (widget.items.isNotEmpty) {
      final requested = widget.initialItemId;
      final initial = widget.items.any((item) => item.id == requested)
          ? requested!
          : widget.items.first.id;
      _openIds.add(initial);
      _activeId = initial;
    }
  }

  @override
  void didUpdateWidget(covariant BackofficeWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final validIds = widget.items.map((item) => item.id).toSet();
    _openIds.removeWhere((id) => !validIds.contains(id));
    if (_activeId != null && !validIds.contains(_activeId)) {
      _activeId = _openIds.isEmpty ? null : _openIds.last;
    }
    if (_activeId == null && widget.items.isNotEmpty) {
      _activeId = widget.items.first.id;
      if (!_openIds.contains(_activeId)) _openIds.add(_activeId!);
    }
  }

  void _open(String id) {
    if (!widget.items.any((item) => item.id == id)) return;
    setState(() {
      if (!_openIds.contains(id)) _openIds.add(id);
      _activeId = id;
    });
  }

  Future<void> _close(String id) async {
    final item = widget.items
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (item == null || !item.closable) return;
    final allowed = await widget.onCloseRequested?.call(item) ?? true;
    if (!allowed || !mounted) return;
    setState(() {
      final oldIndex = _openIds.indexOf(id);
      _openIds.remove(id);
      if (_activeId == id) {
        if (_openIds.isEmpty) {
          _activeId = null;
        } else {
          _activeId = _openIds[oldIndex.clamp(0, _openIds.length - 1)];
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = <BackofficeWorkspaceItem>[
      for (final id in _openIds)
        for (final item in widget.items)
          if (item.id == id) item,
    ];
    final index = visible.indexWhere((item) => item.id == _activeId);

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            BackofficeSidebar(
              items: [
                for (final item in widget.items)
                  BackofficeNavItem(
                    id: item.id,
                    label: item.label,
                    icon: item.icon,
                    group: item.group,
                  ),
              ],
              activeId: _activeId ?? '',
              collapsed: _collapsed,
              onCollapsedChanged: (value) => setState(() => _collapsed = value),
              onSelected: _open,
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 48,
                    color: scheme.surfaceContainerLow,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'SmooControl · Backoffice',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final item in visible)
                          Semantics(
                            selected: item.id == _activeId,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _open(item.id),
                                  icon: Icon(item.icon, size: 16),
                                  label: Text(item.label),
                                  style: TextButton.styleFrom(
                                    backgroundColor: item.id == _activeId
                                        ? scheme.primaryContainer
                                        : Colors.transparent,
                                    foregroundColor: scheme.onSurface,
                                  ),
                                ),
                                if (item.closable)
                                  IconButton(
                                    onPressed: () => _close(item.id),
                                    tooltip: 'Cerrar ${item.label}',
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: index < 0
                        ? Center(
                            child: Text(
                              'Seleccioná un módulo',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          )
                        : IndexedStack(
                            index: index,
                            children: [
                              for (final item in visible)
                                KeyedSubtree(
                                  key: ValueKey(item.id),
                                  child: widget.pageBuilder(context, item),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
