import 'package:flutter/material.dart';

import '../config/theme.dart';

/// The Madrasa monogram, drawn natively (no SVG dependency) so it stays crisp at
/// any size. An "M" whose center valley dips like an open book, on a gold shelf,
/// optionally inside a rounded-square frame. Mirrors assets/logo/madrasa_*.svg.
class MadrasaLogo extends StatelessWidget {
  const MadrasaLogo({
    super.key,
    this.size = 96,
    this.markColor = AppTheme.seed,
    this.shelfColor = AppTheme.gold,
    this.framed = true,
  });

  /// Convenience for placing the mark on a brand-teal surface (splash, headers).
  const MadrasaLogo.onDark({super.key, this.size = 96})
      : markColor = Colors.white,
        shelfColor = AppTheme.gold,
        framed = true;

  final double size;
  final Color markColor;
  final Color shelfColor;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MadrasaLogoPainter(
          markColor: markColor,
          shelfColor: shelfColor,
          framed: framed,
        ),
      ),
    );
  }
}

class _MadrasaLogoPainter extends CustomPainter {
  _MadrasaLogoPainter({
    required this.markColor,
    required this.shelfColor,
    required this.framed,
  });

  final Color markColor;
  final Color shelfColor;
  final bool framed;

  // Geometry authored on a 200×200 grid (matches the SVG source), scaled to fit.
  static const _grid = 200.0;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _grid;
    Offset p(double x, double y) => Offset(x * k, y * k);

    if (framed) {
      final frame = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * k
        ..color = markColor;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(14 * k, 14 * k, 172 * k, 172 * k),
        Radius.circular(42 * k),
      );
      canvas.drawRRect(rect, frame);
    }

    final m = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15 * k
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = markColor;
    final path = Path()
      ..moveTo(p(52, 146).dx, p(52, 146).dy)
      ..lineTo(p(52, 66).dx, p(52, 66).dy)
      ..lineTo(p(100, 110).dx, p(100, 110).dy)
      ..lineTo(p(148, 66).dx, p(148, 66).dy)
      ..lineTo(p(148, 146).dx, p(148, 146).dy);
    canvas.drawPath(path, m);

    final shelf = Paint()..color = shelfColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(52 * k, 158 * k, 96 * k, 9 * k),
        Radius.circular(4.5 * k),
      ),
      shelf,
    );
  }

  @override
  bool shouldRepaint(_MadrasaLogoPainter old) =>
      old.markColor != markColor ||
      old.shelfColor != shelfColor ||
      old.framed != framed;
}
