import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_search_field.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:smoo_control/features/catalog/presentation/bloc/catalog_event.dart';
import 'package:smoo_control/features/catalog/presentation/bloc/catalog_state.dart';
import 'package:smoo_control/features/catalog/presentation/widgets/catalog_tree_list.dart';
import 'package:smoo_control/features/catalog/presentation/widgets/create_category_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Product category management page.
class CatalogPage extends StatelessWidget {
  /// Creates the catalog page.
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) =>
          serviceLocator<CatalogBloc>()..add(const CatalogLoadRequested()),
      child: Builder(
        builder: (context) => AppPageScaffold(
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openCreateDialog(context),
              tooltip: l10n.createAction,
            ),
          ],
          title: l10n.moduleCatalog,
          body: BlocConsumer<CatalogBloc, CatalogState>(
            listener: (context, state) {
              final messenger = ScaffoldMessenger.of(context);
              switch (state) {
                case CatalogLoaded(:final notice) when notice != null:
                  messenger.showSnackBar(SnackBar(content: Text(notice)));
                case CatalogFailure(:final failure):
                  messenger.showSnackBar(
                    SnackBar(content: Text(failure.message)),
                  );
                default:
                  break;
              }
            },
            builder: (context, state) {
              return switch (state) {
                CatalogInitial() || CatalogLoading() => const AppLoadingPage(),
                CatalogFailure(:final failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  message: failure.message,
                  title: l10n.moduleCatalog,
                ),
                CatalogLoaded(:final categories) when categories.isEmpty =>
                  AppEmptyState(
                    icon: Icons.category_outlined,
                    message: l10n.emptyCatalogMessage,
                    title: l10n.emptyCatalogTitle,
                  ),
                CatalogLoaded(:final categories) => _CatalogSearchableTree(
                  categories: categories,
                  onEdit: (category) => _openEditDialog(
                    context,
                    category,
                    categories,
                  ),
                  onRemove: (category) => _confirmRemoveLevel(
                    context,
                    category,
                  ),
                ),
              };
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final categories = switch (context.read<CatalogBloc>().state) {
      CatalogLoaded(:final categories) => categories,
      _ => <ProductCategory>[],
    };
    final category = await showDialog<ProductCategory>(
      context: context,
      builder: (_) => CreateCategoryDialog(categories: categories),
    );

    if (category != null && context.mounted) {
      context.read<CatalogBloc>().add(CatalogCategorySaved(category));
    }
  }

  Future<void> _openEditDialog(
    BuildContext context,
    ProductCategory category,
    List<ProductCategory> categories,
  ) async {
    final updated = await showDialog<ProductCategory>(
      context: context,
      builder: (_) => CreateCategoryDialog(
        category: category,
        categories: categories,
      ),
    );

    if (updated != null && context.mounted) {
      context.read<CatalogBloc>().add(CatalogCategorySaved(updated));
    }
  }

  Future<void> _confirmRemoveLevel(
    BuildContext context,
    ProductCategory category,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.removeCategoryLevelTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.removeCategoryLevelMessage(category.name)),
            const SizedBox(height: 12),
            Text(l10n.removeCategoryLevelWithChildrenMessage),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.removeCategoryLevelConfirm),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && context.mounted) {
      context.read<CatalogBloc>().add(CatalogCategoryRemoved(category));
    }
  }
}

class _CatalogSearchableTree extends StatefulWidget {
  const _CatalogSearchableTree({
    required this.categories,
    required this.onEdit,
    required this.onRemove,
  });

  final List<ProductCategory> categories;
  final ValueChanged<ProductCategory> onEdit;
  final ValueChanged<ProductCategory> onRemove;

  @override
  State<_CatalogSearchableTree> createState() => _CatalogSearchableTreeState();
}

class _CatalogSearchableTreeState extends State<_CatalogSearchableTree> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: AppSearchField(
            controller: _controller,
            label: l10n.searchField,
            onChanged: (value) => setState(() => _query = value),
            onClear: _clearSearch,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: CatalogTreeList(
            categories: widget.categories,
            searchQuery: _query,
            onEdit: widget.onEdit,
            onRemove: widget.onRemove,
          ),
        ),
      ],
    );
  }

  void _clearSearch() {
    _controller.clear();
    setState(() => _query = '');
  }
}
