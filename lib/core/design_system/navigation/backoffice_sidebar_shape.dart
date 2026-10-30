import 'package:flutter/material.dart';

/// Shared curved background, separated to keep widgets focused.
class BackofficeSidebarShapePainter extends CustomPainter {
  const BackofficeSidebarShapePainter({
    required this.baseWidth,
    required this.protrusion,
    required this.fill,
    required this.edge,
  });

  final double baseWidth;
  final double protrusion;
  final Color fill;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.height / 2;
    const halfNotch = 38.0;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(baseWidth, 0)
      ..lineTo(baseWidth, center - halfNotch)
      ..cubicTo(
        baseWidth,
        center - 22,
        baseWidth + protrusion,
        center - 22,
        baseWidth + protrusion,
        center,
      )
      ..cubicTo(
        baseWidth + protrusion,
        center + 22,
        baseWidth,
        center + 22,
        baseWidth,
        center + halfNotch,
      )
      ..lineTo(baseWidth, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    final edgePaint = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(path, edgePaint);
  }

  @override
  bool shouldRepaint(covariant BackofficeSidebarShapePainter old) =>
      baseWidth != old.baseWidth ||
      protrusion != old.protrusion ||
      fill != old.fill ||
      edge != old.edge;
}
