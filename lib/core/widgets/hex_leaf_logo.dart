import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The EcoConnect hexagon-with-leaf brand mark, drawn as a vector so it stays
/// crisp at any size.
class HexLeafLogo extends StatelessWidget {
  const HexLeafLogo({
    super.key,
    this.size = 48,
    this.color = AppColors.forest,
    this.leafColor,
    this.strokeWidth = 2.4,
    this.filled = false,
  });

  final double size;
  final Color color;
  final Color? leafColor;
  final double strokeWidth;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _HexLeafPainter(
        color: color,
        leafColor: leafColor ?? color,
        strokeWidth: strokeWidth,
        filled: filled,
      ),
    );
  }
}

class _HexLeafPainter extends CustomPainter {
  _HexLeafPainter({
    required this.color,
    required this.leafColor,
    required this.strokeWidth,
    required this.filled,
  });

  final Color color;
  final Color leafColor;
  final double strokeWidth;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);

    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final point = Offset(
        center.dx + r * 0.92 * math.cos(angle),
        center.dy + r * 0.92 * math.sin(angle),
      );
      if (i == 0) {
        hex.moveTo(point.dx, point.dy);
      } else {
        hex.lineTo(point.dx, point.dy);
      }
    }
    hex.close();

    canvas.drawPath(
      hex,
      Paint()
        ..color = color
        ..isAntiAlias = true
        ..strokeJoin = StrokeJoin.round
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final leafRadius = r * 0.44;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.35);

    final leaf = Path()
      ..moveTo(0, -leafRadius)
      ..quadraticBezierTo(leafRadius * 1.1, -leafRadius * 0.1, 0, leafRadius)
      ..quadraticBezierTo(-leafRadius * 1.1, -leafRadius * 0.1, 0, -leafRadius)
      ..close();

    canvas.drawPath(
      leaf,
      Paint()
        ..color = filled ? Colors.white : leafColor
        ..isAntiAlias = true
        ..style = PaintingStyle.fill,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HexLeafPainter old) =>
      old.color != color ||
      old.leafColor != leafColor ||
      old.strokeWidth != strokeWidth ||
      old.filled != filled;
}
