import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_touch_grid.dart';

/// Dynamic root category band for tablet POS.
class PosCategoryBand extends StatelessWidget {
  /// Creates the category band.
  const PosCategoryBand({
    required this.state,
    this.onCategorySelected,
    super.key,
  });

  /// Current POS state.
  final PosReady state;

  /// Called when the operator navigates to one category.
  final VoidCallback? onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final roots = _rootCategories();
    final activeRootId = _activeRootId();
    return PosTouchGrid(
      children: [
        for (final category in roots)
          PosTouchButton(
            label: category.name,
            onPressed: () {
              onCategorySelected?.call();
              context.read<PosBloc>().add(PosCategorySelected(category.id));
            },
            selected: category.id == activeRootId,
          ),
      ],
    );
  }

  String? _activeRootId() {
    final selected = state.selectedCategoryId;
    if (selected == null) {
      final roots = _rootCategories();
      return roots.isEmpty ? null : roots.first.id;
    }
    var current = _categoryById(selected);
    while (current?.parentId != null) {
      current = _categoryById(current!.parentId!);
    }
    return current?.id;
  }

  List<ProductCategory> _rootCategories() {
    return state.categories.where((category) {
        return category.isActive && category.parentId == null;
      }).toList()
      ..sort((first, second) => first.sortOrder.compareTo(second.sortOrder));
  }

  ProductCategory? _categoryById(String id) {
    for (final category in state.categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}
