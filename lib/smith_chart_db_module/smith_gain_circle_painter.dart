import 'dart:math';
import 'package:flutter/material.dart';
import 'package:equations/equations.dart';

class GainCircleData {
  final Complex center;
  final double radius;
  final String label;
  final Color color;
  GainCircleData({
    required this.center,
    required this.radius,
    required this.label,
    required this.color,
  });
}

class SmithGainCirclePainter extends StatelessWidget {
  final List<GainCircleData> gainCircles;
  final Complex? userPoint;
  final double canvasSize;

  const SmithGainCirclePainter({
    super.key,
    required this.gainCircles,
    this.userPoint,
    this.canvasSize = 420,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: canvasSize,
        height: canvasSize,
        child: CustomPaint(
          painter: _SmithGainPainter(
            gainCircles: gainCircles,
            userPoint: userPoint,
          ),
        ),
      ),
    );
  }
}

class _SmithGainPainter extends CustomPainter {
  final List<GainCircleData> gainCircles;
  final Complex? userPoint;

  final List<Color> circleColors = [
    Colors.blueAccent,    // 亮蓝
    Colors.green,         // 绿
    Colors.redAccent,     // 亮红
    Colors.purpleAccent,  // 紫
    Colors.orange,        // 橙
    Colors.teal,          // 青
    Colors.indigoAccent,  // 靛蓝
    Colors.pink,          // 粉
  ];

  _SmithGainPainter({
    required this.gainCircles,
    this.userPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double scale = size.width / 2;
    final smithCenter = Offset(scale, scale);


    final smithPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(smithCenter, scale, smithPaint);

    final axisPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(scale, 0), Offset(scale, size.height), axisPaint);
    canvas.drawLine(Offset(0, scale), Offset(size.width, scale), axisPaint);

    final rValues = [0.2, 0.5, 1, 2, 5];
    final rPaint = Paint()
      ..color = Colors.red.withOpacity(0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05;
    for (final r in rValues) {
      final cx = r / (1 + r);
      final radius = 1 / (1 + r);
      final center = Offset(cx * scale + scale, scale);
      final rRadius = radius * scale;
      canvas.drawCircle(center, rRadius, rPaint);

      final x0 = (cx - radius) * scale + scale;
      final y0 = scale;
      final label = TextPainter(
        text: TextSpan(
          text: 'r=${r.toString()}',
          style: const TextStyle(color: Colors.red, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      );
      label.layout();
      label.paint(canvas, Offset(x0 - label.width - 4, y0 + 4));
    }

    final xValues = [-5, -2, -1, -0.5, -0.2, 5, 2, 1, 0.5, 0.2];
    final Map<double, double> jLabelSwap = {
      5: 0.2, 2: 0.5, 1: 1, 0.5: 2, 0.2: 5,
      -5: -0.2, -2: -0.5, -1: -1, -0.5: -2, -0.2: -5,
    };

    final xPaint = Paint()
      ..color = Colors.blue.withOpacity(0.36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05;

    for (final x in xValues) {
      if (x.abs() < 1e-8) continue;
      final cx = 1.0;
      final cy = 1 / x;
      final radius = 1 / x.abs();

      Path arcPath = Path();
      bool started = false;
      for (double theta = 0; theta < 2 * pi; theta += 0.003) {
        double px = cx + radius * cos(theta);
        double py = cy + radius * sin(theta);
        if (px * px + py * py <= 1.0001) { // 裁剪在单位圆内
          final p = Offset(px * scale + scale, scale - py * scale);
          if (!started) {
            arcPath.moveTo(p.dx, p.dy);
            started = true;
          } else {
            arcPath.lineTo(p.dx, p.dy);
          }
        } else {
          started = false;
        }
      }
      canvas.drawPath(arcPath, xPaint);

      double denom = (x * x + 1);
      double x_left = (-x * x + 1) / denom;
      double y_up = sqrt(1 - x_left * x_left);
      double y_down = -y_up;

      if (x > 0) {
        double labelValue = (jLabelSwap[x] ?? x.toDouble());
        final pos = Offset(x_left * scale + scale, scale - y_up * scale);
        final label = TextPainter(
          text: TextSpan(
            text: '+${labelValue.abs()}j',
            style: const TextStyle(color: Colors.blue, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        );
        label.layout();
        label.paint(canvas, Offset(pos.dx - label.width - 3, pos.dy - 7));

        double labelValueNeg = (jLabelSwap[-x] ?? (-x).toDouble());
        final posNeg = Offset(x_left * scale + scale, scale - y_down * scale);
        final labelNeg = TextPainter(
          text: TextSpan(
            text: '-${labelValueNeg.abs()}j',
            style: const TextStyle(color: Colors.blue, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        );
        labelNeg.layout();
        labelNeg.paint(canvas, Offset(posNeg.dx - labelNeg.width - 3, posNeg.dy + 2));
      }
    }

    int specialPointCount = 0;

    for (int i = 0; i < gainCircles.length; i++) {
      final c = gainCircles[i];
      final Color drawColor = c.color != Colors.blueAccent ? c.color : circleColors[i % circleColors.length];

      final center = Offset(c.center.real * scale + scale, scale - c.center.imaginary * scale);
      final radius = c.radius * scale;

      if (c.radius < 1e-6) {
        final pointOutlinePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 8.5, pointOutlinePaint);

        final pointFillPaint = Paint()
          ..color = drawColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 6.5, pointFillPaint);

        final textSpan = TextSpan(
          text: c.label,
          style: TextStyle(
            color: drawColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            shadows: const [
              Shadow(offset: Offset(1.2, 1.2), blurRadius: 2.0, color: Colors.white),
              Shadow(offset: Offset(-1.2, -1.2), blurRadius: 2.0, color: Colors.white),
            ],
          ),
        );
        final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        tp.layout();

        // 智能避让：把标签分散到4个不同象限 (-45°, 135°, 45°, -135°)
        final List<double> escapeAngles = [-pi / 4, 3 * pi / 4, pi / 4, -3 * pi / 4];
        double ang = escapeAngles[specialPointCount % escapeAngles.length];
        specialPointCount++;

        double dist = 12.0;
        double dx = dist * cos(ang);
        double dy = dist * sin(ang);

        double shiftX = (cos(ang) >= 0) ? 0.0 : -tp.width;
        double shiftY = (sin(ang) >= 0) ? 0.0 : -tp.height;

        tp.paint(canvas, center + Offset(dx, dy) + Offset(shiftX, shiftY));

        continue;
      }

      final circlePaint = Paint()
        ..color = drawColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, radius, circlePaint);

      final centerPaint = Paint()
        ..color = drawColor.withOpacity(0.8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 4, centerPaint);

      final textSpan = TextSpan(
        text: c.label,
        style: TextStyle(
          color: drawColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          shadows: const [
            Shadow(offset: Offset(1.2, 1.2), blurRadius: 2.0, color: Colors.white),
            Shadow(offset: Offset(-1.2, -1.2), blurRadius: 2.0, color: Colors.white),
          ],
        ),
      );

      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      tp.layout();

      double angleStep = pi / 7;
      double startAngle = -pi / 3;
      double currentAngle = startAngle - (i * angleStep);
      double dist = max(radius + 4.0, 20.0);
      double dx = dist * cos(currentAngle);
      double dy = dist * sin(currentAngle);

      Offset labelPos = center + Offset(dx, dy);

      double shiftX = (cos(currentAngle) >= 0) ? 2.0 : -tp.width - 2.0;
      double shiftY = -tp.height / 2;

      tp.paint(canvas, labelPos + Offset(shiftX, shiftY));
    }

    if (userPoint != null) {
      final x = userPoint!.real * scale + scale;
      final y = -userPoint!.imaginary * scale + scale;

      final outlinePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 8, outlinePaint);

      final paint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 6, paint);
    }

    final centerText = TextPainter(
      text: const TextSpan(
        text: "Smith Center",
        style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    centerText.layout();
    centerText.paint(canvas, smithCenter + const Offset(10, 10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}