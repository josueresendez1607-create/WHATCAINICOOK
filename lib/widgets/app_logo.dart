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
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  static final _gold = Paint()
    ..color = AppColors.gold
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;

  static final _goldSoft = Paint()
    ..color = AppColors.gold.withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.46;

    canvas.drawCircle(center, radius, _goldSoft);

    // Plato.
    canvas.drawCircle(center, radius * 0.66, _gold);
    canvas.drawCircle(center, radius * 0.46, _goldSoft);

    // Cubiertos estilizados.
    final forkX = center.dx - radius * 0.30;
    final knifeX = center.dx + radius * 0.30;
    final top = center.dy - radius * 0.52;
    final bottom = center.dy + radius * 0.52;

    canvas.drawLine(Offset(forkX, top), Offset(forkX, bottom), _gold);
    for (var i = -1; i <= 1; i++) {
      final x = forkX + i * radius * 0.09;
      canvas.drawLine(Offset(x, top), Offset(x, top + radius * 0.20), _gold);
    }

    canvas.drawLine(Offset(knifeX, top), Offset(knifeX, bottom), _gold);
    canvas.drawLine(
      Offset(knifeX + radius * 0.10, top),
      Offset(knifeX + radius * 0.10, top + radius * 0.30),
      _gold,
    );

    // Chispa de IA.
    final spark = Offset(center.dx, top - radius * 0.20);
    final s = radius * 0.16;
    canvas.drawLine(spark - Offset(s, 0), spark + Offset(s, 0), _gold);
    canvas.drawLine(spark - Offset(0, s), spark + Offset(0, s), _gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
