import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:smoo_control/features/products/presentation/pages/canonical_items_content.dart';

/// Presents the canonical item master in the authenticated Products route.
class ArticlesPage extends StatelessWidget {
  /// Creates the item catalog, optionally scoped to the packaging bookmark.
  const ArticlesPage({this.initialType = 'all', super.key});

  /// Retains the old packaging bookmark as a canonical class filter.
  final String initialType;

  @override
  Widget build(BuildContext context) => AppPageScaffold(
    title: 'Productos',
    body: CanonicalItemsContent(
      initialClassFilter: initialType == 'packaging'
          ? CanonicalItemClass.packaging
          : null,
    ),
  );
}
