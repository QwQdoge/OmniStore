import 'package:flutter/material.dart';

/// Canonical Meo AI identity: a filled AI monogram and one sparkle on the
/// supplied lavender rounded-square. The brand colors are intentionally fixed
/// so an AI entry point remains recognisable across dynamic app themes.
class AiMark extends StatelessWidget {
  const AiMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'AI',
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: const _AiMarkPainter(),
        ),
      ),
    );
  }
}

class _AiMarkPainter extends CustomPainter {
  const _AiMarkPainter();

  static const _background = Color(0xFFA289ED);
  static const _foreground = Color(0xFFFEFEFE);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(14.5 * scale),
      ),
      Paint()..color = _background,
    );

    final markPaint = Paint()..color = _foreground;
    final letterA = Path()
      ..moveTo(10.8 * scale, 43.6 * scale)
      ..lineTo(20.8 * scale, 24.1 * scale)
      ..cubicTo(
        21.9 * scale,
        22.0 * scale,
        23.5 * scale,
        21.5 * scale,
        25.5 * scale,
        21.5 * scale,
      )
      ..cubicTo(
        27.5 * scale,
        21.5 * scale,
        29.1 * scale,
        22.1 * scale,
        30.2 * scale,
        24.1 * scale,
      )
      ..lineTo(40.2 * scale, 43.7 * scale)
      ..cubicTo(
        41.7 * scale,
        46.7 * scale,
        40.5 * scale,
        49.3 * scale,
        37.9 * scale,
        49.3 * scale,
      )
      ..cubicTo(
        36.2 * scale,
        49.3 * scale,
        35.0 * scale,
        48.4 * scale,
        34.2 * scale,
        46.8 * scale,
      )
      ..lineTo(25.5 * scale, 29.8 * scale)
      ..lineTo(18.6 * scale, 43.2 * scale)
      ..lineTo(25.2 * scale, 43.2 * scale)
      ..cubicTo(
        27.8 * scale,
        43.2 * scale,
        29.6 * scale,
        44.5 * scale,
        29.6 * scale,
        46.25 * scale,
      )
      ..cubicTo(
        29.6 * scale,
        48.0 * scale,
        27.8 * scale,
        49.3 * scale,
        25.2 * scale,
        49.3 * scale,
      )
      ..lineTo(15.2 * scale, 49.3 * scale)
      ..cubicTo(
        12.0 * scale,
        49.3 * scale,
        9.4 * scale,
        46.7 * scale,
        10.8 * scale,
        43.6 * scale,
      )
      ..close();
    canvas.drawPath(letterA, markPaint);
    canvas.drawRRect(
      RRect.fromLTRBR(
        41.85 * scale,
        21.5 * scale,
        48.75 * scale,
        49.3 * scale,
        Radius.circular(3.45 * scale),
      ),
      markPaint,
    );

    final sparkle = Path()
      ..moveTo(51.9 * scale, 8.6 * scale)
      ..cubicTo(
        52.55 * scale,
        11.35 * scale,
        53.55 * scale,
        12.85 * scale,
        56.9 * scale,
        13.65 * scale,
      )
      ..cubicTo(
        53.55 * scale,
        14.45 * scale,
        52.55 * scale,
        15.95 * scale,
        51.9 * scale,
        18.55 * scale,
      )
      ..cubicTo(
        51.25 * scale,
        15.95 * scale,
        50.25 * scale,
        14.45 * scale,
        46.9 * scale,
        13.65 * scale,
      )
      ..cubicTo(
        50.25 * scale,
        12.85 * scale,
        51.25 * scale,
        11.35 * scale,
        51.9 * scale,
        8.6 * scale,
      )
      ..close();
    canvas.drawPath(sparkle, markPaint);
  }

  @override
  bool shouldRepaint(covariant _AiMarkPainter oldDelegate) => false;
}
