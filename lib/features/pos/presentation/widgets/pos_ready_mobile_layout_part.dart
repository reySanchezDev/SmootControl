part of 'pos_ready_view.dart';

class _PosMobileLayout extends StatelessWidget {
  const _PosMobileLayout({
    required this.actionsBand,
    required this.catalog,
    required this.categoryBand,
    required this.categoryHeight,
    required this.mobileCatalogMode,
    required this.productsVisible,
    required this.tableBand,
    required this.ticket,
  });

  static const double _tableBandHeight = 76;
  static const double _actionsBandHeight = 76;

  final Widget actionsBand;
  final Widget catalog;
  final Widget categoryBand;
  final double categoryHeight;
  final bool mobileCatalogMode;
  final bool productsVisible;
  final Widget tableBand;
  final Widget ticket;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!mobileCatalogMode)
          Expanded(
            flex: productsVisible ? 5 : 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: ticket,
            ),
          ),
        if (productsVisible)
          Expanded(
            flex: mobileCatalogMode ? 1 : 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: catalog,
            ),
          ),
        const Divider(height: 1),
        SizedBox(height: categoryHeight, child: categoryBand),
        const Divider(height: 1),
        SizedBox(
          height: _tableBandHeight,
          child: tableBand,
        ),
        const Divider(height: 1),
        SizedBox(height: _actionsBandHeight, child: actionsBand),
      ],
    );
  }
}
