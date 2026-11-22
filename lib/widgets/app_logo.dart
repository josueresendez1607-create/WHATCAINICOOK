import 'package:flutter/material.dart';
import 'package:whatcanicook/core/theme.dart';

/// Logotipo original de WHATCANICOOK dibujado en vectores.
///
/// Plato + cubiertos + chispa de IA en acento dorado sobre grafito.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.height = 54,
    this.width,
    this.showText = true,
  });

  final double height;
  final double? width;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      height: height,
      width: width ?? height,
      child: CustomPaint(painter: const _LogoPainter()),
    );

    if (!showText) return mark;

    return LayoutBuilder(
      builder: (context, constraints) {
        // En pantallas estrechas el texto no cabe junto al botón de
        // configuración; mostramos solo el símbolo para evitar overflow.
        if (constraints.hasBoundedWidth && constraints.maxWidth < 210) {
          return mark;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            mark,
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'WHATCANICOOK',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'COOK SMARTER',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.6,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  static final _gold = Paint()
    ..color = AppColors.gold
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final _goldSoft = Paint()
    ..color = AppColors.gold.withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..strokeCap = StrokeCap.round;

  static final _goldFill = Paint()
    ..color = AppColors.gold.withValues(alpha: 0.12)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.46;

    // Marco circular.
    canvas.drawCircle(center, r, _goldSoft);
    canvas.drawCircle(center, r * 0.92, _goldFill);

    // Tazón/plato hondo (relacionado a comida).
    final bowlRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + r * 0.18),
      width: r * 1.18,
      height: r * 0.72,
    );
    final bowl = Path()
      ..moveTo(bowlRect.left, bowlRect.top)
      ..quadraticBezierTo(
        bowlRect.left,
        bowlRect.bottom,
        center.dx,
        bowlRect.bottom,
      )
      ..quadraticBezierTo(
        bowlRect.right,
        bowlRect.bottom,
        bowlRect.right,
        bowlRect.top,
      );
    canvas.drawPath(bowl, _gold);

    // Borde superior del tazón.
    canvas.drawLine(
      Offset(bowlRect.left - r * 0.04, bowlRect.top),
      Offset(bowlRect.right + r * 0.04, bowlRect.top),
      _gold,
    );

    // Base pequeña.
    canvas.drawLine(
      Offset(center.dx - r * 0.18, bowlRect.bottom),
      Offset(center.dx + r * 0.18, bowlRect.bottom),
      _goldSoft,
    );

    // Hojita/ingrediente fresco sobre el tazón.
    final leafCenter = Offset(center.dx + r * 0.10, center.dy - r * 0.02);
    final leaf = Path()
      ..moveTo(leafCenter.dx - r * 0.18, leafCenter.dy + r * 0.10)
      ..quadraticBezierTo(
        leafCenter.dx - r * 0.02,
        leafCenter.dy - r * 0.22,
        leafCenter.dx + r * 0.22,
        leafCenter.dy - r * 0.08,
      )
      ..quadraticBezierTo(
        leafCenter.dx + r * 0.08,
        leafCenter.dy + r * 0.16,
        leafCenter.dx - r * 0.18,
        leafCenter.dy + r * 0.10,
      );
    canvas.drawPath(leaf, _goldSoft);
    canvas.drawLine(
      Offset(leafCenter.dx - r * 0.14, leafCenter.dy + r * 0.08),
      Offset(leafCenter.dx + r * 0.16, leafCenter.dy - r * 0.05),
      _goldSoft,
    );

    // Vapor/calor (comida recién preparada).
    void steam(double x, double height, double phase) {
      final top = center.dy - r * 0.62;
      final path = Path()..moveTo(center.dx + x, top + height);
      path.quadraticBezierTo(
        center.dx + x + phase,
        top + height * 0.66,
        center.dx + x,
        top + height * 0.33,
      );
      path.quadraticBezierTo(
        center.dx + x - phase,
        top + height * 0.12,
        center.dx + x + phase * 0.35,
        top,
      );
      canvas.drawPath(path, _gold);
    }

    steam(-r * 0.22, r * 0.34, r * 0.07);
    steam(0, r * 0.40, r * 0.08);
    steam(r * 0.22, r * 0.34, r * 0.07);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
