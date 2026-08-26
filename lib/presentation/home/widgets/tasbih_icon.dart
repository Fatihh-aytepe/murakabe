import 'dart:math';
import 'package:flutter/material.dart';

/// Basit, tek renkli bir tespih (misbaha) çizimi — soldan açılan menüdeki
/// "Zikir" satırının simgesi. Material ikon setinde tespihi karşılayan bir
/// glyph olmadığı için CustomPainter ile çiziliyor: halka şeklinde dizilmiş
/// boncuklar + alt ortada sarkan bir imam boncuğu/püskül.
///
/// Diğer menü satırlarındaki `Icon(...)` ile aynı 20dp alana oturacak
/// şekilde tasarlandı; rengi menü öğesinin aktif/pasif rengiyle eşleşsin
/// diye dışarıdan [color] olarak veriliyor.
class TasbihIcon extends StatelessWidget {
  final Color color;
  final double size;

  const TasbihIcon({super.key, required this.color, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TasbihPainter(color: color)),
    );
  }
}

class _TasbihPainter extends CustomPainter {
  final Color color;

  _TasbihPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final ringRadius = size.width * 0.34;
    final beadRadius = size.width * 0.075;
    const beadCount = 10;

    final stringPaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;
    final beadPaint = Paint()..color = color;

    // Boncukların dizildiği halka (iplik).
    canvas.drawCircle(center, ringRadius, stringPaint);

    for (int i = 0; i < beadCount; i++) {
      final angle = (2 * pi * i / beadCount) - pi / 2;
      final pos = center +
          Offset(cos(angle) * ringRadius, sin(angle) * ringRadius);
      canvas.drawCircle(pos, beadRadius, beadPaint);
    }

    // İmam boncuğu ve sarkan püskül ipliği — alt ortada, halkadan taşar.
    final tasselTop = Offset(center.dx, center.dy + ringRadius);
    final tasselBottom = Offset(center.dx, size.height * 0.95);
    canvas.drawLine(tasselTop, tasselBottom, stringPaint);
    canvas.drawCircle(
      Offset(center.dx, size.height * 0.9),
      beadRadius * 1.2,
      beadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TasbihPainter oldDelegate) =>
      oldDelegate.color != color;
}
