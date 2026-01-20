import 'dart:math';
import 'package:flutter/material.dart';
import 'package:equations/equations.dart';

// 增益圆数据结构
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

// Smith+增益圆可视化控件
class SmithGainCirclePainter extends StatelessWidget {
  final List<GainCircleData> gainCircles;
  final double canvasSize;

  const SmithGainCirclePainter({
    super.key,
    required this.gainCircles,
    this.canvasSize = 420,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: canvasSize,
        height: canvasSize,
        child: CustomPaint(
          painter: _SmithGainPainter(gainCircles: gainCircles),
        ),
      ),
    );
  }
}

class _SmithGainPainter extends CustomPainter {
  final List<GainCircleData> gainCircles;

  // 鲜艳的颜色列表，用于循环分配给增益圆
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

  _SmithGainPainter({required this.gainCircles});

  @override
  void paint(Canvas canvas, Size size) {
    double scale = size.width / 2;
    final smithCenter = Offset(scale, scale);

    // ================= 1. 绘制史密斯圆图背景 (保持原样) =================

    // 1.1 单位Smith圆
    final smithPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(smithCenter, scale, smithPaint);

    // 1.2 坐标轴
    final axisPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(scale, 0), Offset(scale, size.height), axisPaint);
    canvas.drawLine(Offset(0, scale), Offset(size.width, scale), axisPaint);

    // 1.3 等实部圆（r-circles）
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

      // 标注
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

    // 1.4 等虚部圆（x-circles）
    final xValues = [-5, -2, -1, -0.5, -0.2, 5, 2, 1, 0.5, 0.2];
    // 交换映射（Label Correction）
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

      // 标注 +j/-j
      double denom = (x * x + 1);
      double x_left = (-x * x + 1) / denom;
      double y_up = sqrt(1 - x_left * x_left);
      double y_down = -y_up;

      if (x > 0) {
        // +j
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

        // -j
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

    // ================= 2. 绘制增益圆 (重点优化部分) =================

    for (int i = 0; i < gainCircles.length; i++) {
      final c = gainCircles[i];
      // 循环选取鲜艳颜色
      final Color uniqueColor = circleColors[i % circleColors.length];

      final center = Offset(c.center.real * scale + scale, scale - c.center.imaginary * scale);
      final radius = c.radius * scale;

      // 2.1 画增益圆的外圈
      final circlePaint = Paint()
        ..color = uniqueColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, radius, circlePaint);

      // 2.2 画圆心
      final centerPaint = Paint()
        ..color = uniqueColor.withOpacity(0.8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 4, centerPaint);

      // 2.3 绘制标签 (新逻辑：分散在圆周上)
      final textSpan = TextSpan(
        text: c.label,
        style: TextStyle(
          color: uniqueColor,
          fontWeight: FontWeight.bold,
          fontSize: 15,
          shadows: [
            // 双重阴影，增强文字在网格线上的可读性
            Shadow(offset: const Offset(1.2, 1.2), blurRadius: 2.0, color: Colors.white),
            Shadow(offset: const Offset(-1.2, -1.2), blurRadius: 2.0, color: Colors.white),
          ],
        ),
      );

      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      tp.layout();

      // --- 核心优化逻辑 ---
      // 1. 角度轮转：第1个圆(i=0)在45度，第2个(i=1)在135度... 每次转90度
      // 这样标签会分散到圆的四个象限，彻底解决重叠问题
      double angleStep = pi / 2;
      double startAngle = -pi / 4; // 起始角度：右上角 (-45度, 因为Y轴向下)
      double currentAngle = startAngle - (i * angleStep); // 逆时针旋转

      // 2. 距离计算：放在圆的边缘 (半径处)
      // 特殊情况：如果圆非常小(缩成一点)，强制把标签往外推一点(25px)，否则标签会盖住圆心
      double dist = max(radius, 25.0);

      // 3. 计算标签在屏幕上的坐标
      // x = center.x + r * cos(theta)
      // y = center.y + r * sin(theta)
      double dx = dist * cos(currentAngle);
      double dy = dist * sin(currentAngle);

      Offset labelPos = center + Offset(dx, dy);

      // 4. 居中绘制：让文字中心对准计算出的点
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
    }

    // 3. Smith圆心标注
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