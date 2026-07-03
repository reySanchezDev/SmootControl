import 'package:flutter/widgets.dart';

/// Constraint-based responsive decisions for POS surfaces.
final class PosResponsiveLayout {
  /// Creates responsive POS layout values from the available constraints.
  const PosResponsiveLayout._({
    required this.compact,
    required this.narrow,
    required this.short,
    required this.maxHeight,
    required this.maxWidth,
  });

  /// Builds a responsive layout profile from real available space.
  factory PosResponsiveLayout.fromConstraints(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final boundedHeight = height.isFinite ? height : 900.0;
    final boundedWidth = width.isFinite ? width : 1200.0;

    return PosResponsiveLayout._(
      compact: boundedWidth < 760,
      narrow: boundedWidth < 900,
      short: boundedHeight < 760,
      maxHeight: boundedHeight,
      maxWidth: boundedWidth,
    );
  }

  /// Whether the whole POS should use a vertically scrollable composition.
  final bool compact;

  /// Whether wide table-style content should switch to compact cards.
  final bool narrow;

  /// Whether vertical space is constrained.
  final bool short;

  /// Bounded height used for proportional section sizing.
  final double maxHeight;

  /// Bounded width used for proportional section sizing.
  final double maxWidth;

  /// Ticket height for scrollable compact POS composition.
  double ticketHeight({
    required int lineCount,
    required bool productsVisible,
  }) {
    if (lineCount == 0) {
      return productsVisible ? 118 : 170;
    }

    final ratio = productsVisible ? .4 : .62;
    final minimum = productsVisible ? 220.0 : 320.0;
    final maximum = productsVisible ? 440.0 : 600.0;
    final visibleLines = lineCount.clamp(1, productsVisible ? 5 : 8);
    final contentAware = 58.0 + visibleLines * 108.0;
    return contentAware
        .clamp(maxHeight * ratio, maximum)
        .clamp(
          minimum,
          maximum,
        );
  }

  /// Catalog height for scrollable compact POS composition.
  double catalogHeight(int visibleItemCount) {
    final rows = visibleItemCount <= 0
        ? 1
        : (visibleItemCount / catalogColumns).ceil();
    final desired = 16 + rows * catalogTileHeight + (rows - 1) * 8;
    return desired.clamp(92.0, maxHeight * .36).clamp(92.0, 340.0);
  }

  /// Height for the category selector in compact composition.
  double categoryBandHeight(int visibleEntryCount) {
    final columns = touchColumns(minTileWidth: 128);
    final rows = visibleEntryCount <= 0
        ? 1
        : (visibleEntryCount / columns).ceil();
    final desired = 8 + rows * 58 + (rows - 1) * 4;
    return desired.clamp(66.0, maxHeight * .22).clamp(66.0, 180.0).toDouble();
  }

  /// Height for the table/account selector in compact composition.
  double tableBandHeight(int visibleEntryCount) {
    if (!compact) return categoryBandHeight(visibleEntryCount);
    final columns = tableColumns;
    final rows = visibleEntryCount <= 0
        ? 1
        : (visibleEntryCount / columns).ceil();
    final desired = 8 + rows * tableTileHeight + (rows - 1) * 6;
    return desired.clamp(88.0, maxHeight * .28).clamp(88.0, 260.0);
  }

  /// Height for the table/account selector in the main wide composition.
  double wideTableBandHeight() {
    return short ? 64.0 : 72.0;
  }

  /// Height for the action/payment band in compact composition.
  double actionsHeight() {
    if (maxWidth < 560) return 76;
    return (maxHeight * .28).clamp(210.0, 360.0);
  }

  /// Height for the action/payment band in the main wide composition.
  double wideActionsHeight() {
    if (maxWidth < 760) return actionsHeight();
    return short ? 76.0 : 82.0;
  }

  /// Catalog columns estimated from available width.
  int get catalogColumns {
    const horizontalPadding = 20.0;
    final availableWidth = (maxWidth - horizontalPadding).clamp(1.0, maxWidth);
    final maxTileWidth = maxWidth < 520 ? 190.0 : 300.0;
    final minColumns = maxWidth < 520 ? 2 : 1;
    return (availableWidth / maxTileWidth).floor().clamp(minColumns, 8);
  }

  /// Table selector columns estimated from available width.
  int get tableColumns {
    final target = maxWidth < 420 ? 132.0 : 150.0;
    return (maxWidth / target).floor().clamp(1, 8);
  }

  /// Product/category tile height for catalog estimates.
  double get catalogTileHeight {
    final columns = catalogColumns;
    final availableWidth = (maxWidth - 20 - (columns - 1) * 8).clamp(
      1.0,
      maxWidth,
    );
    final tileWidth = availableWidth / columns;
    final aspectRatio = maxWidth < 520 ? 1.35 : 2.85;
    final minimum = maxWidth < 520 ? 104.0 : 72.0;
    final maximum = maxWidth < 520 ? 132.0 : 118.0;
    return (tileWidth / aspectRatio).clamp(minimum, maximum);
  }

  /// Table selector tile height for compact grids.
  double get tableTileHeight => maxWidth < 420 ? 70.0 : 76.0;

  /// Number of tactile grid columns that fit in the available width.
  int touchColumns({required double minTileWidth}) {
    return (maxWidth / minTileWidth).floor().clamp(1, 8);
  }
}
