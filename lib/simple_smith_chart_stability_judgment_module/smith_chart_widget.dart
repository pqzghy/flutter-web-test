//说明：绘制史密斯图
import 'package:flutter/material.dart';
import 'package:equations/equations.dart';


class SmithChartWidget extends StatelessWidget {
  final Complex circleCenter;         // 圆心（复数，Γ平面，射频里一般是源或负载稳定圆的圆心）
  final double circleRadius;          // 稳定圆半径
  final double referenceAbs;          // 参考半径（通常是 |S11| 或 |S22|，用来标注/辅助绘制）
  final bool isPotentiallyUnstable;   // 是否潜在不稳定（用来高亮、变色或者警告提示）
  final String label;                 // 圆的标签（如 "Source Stability Circle"）
  final bool showShadow;              // 是否绘制圆阴影（默认 true，增强可视化效果）
  final double canvasSize;            // 绘图区域大小（默认 480 像素，正方形）

  const SmithChartWidget({
    super.key,
    required this.circleCenter,
    required this.circleRadius,
    required this.referenceAbs,
    required this.isPotentiallyUnstable,
    required this.label,
    this.showShadow = true,
    this.canvasSize = 480,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPotentiallyUnstable) return const SizedBox.shrink();//如果该圆不是“潜在不稳定”圆，则什么都不渲染

    return SizedBox(
      width: canvasSize,//限定绘图区的大小，这里是正方形，大小为 canvasSize（默认 480px）。
      height: canvasSize,//限定绘图区的大小，这里是正方形，大小为 canvasSize（默认 480px）。
      child: CustomPaint(//Flutter 画图专用控件。它有一个 painter 属性，接收一个自定义“画家”对象（这里是 SmithChartPainter），负责所有的实际绘制。
        painter: SmithChartPainter(
          circleCenter: circleCenter,
          circleRadius: circleRadius,
          referenceAbs: referenceAbs,
          label: label,
          showShadow: showShadow,
        ),
      ),
    );
  }
}

class SmithChartPainter extends CustomPainter {
  final Complex circleCenter;
  final double circleRadius;
  final double referenceAbs;
  final String label;
  final bool showShadow;

  SmithChartPainter({
    required this.circleCenter,
    required this.circleRadius,
    required this.referenceAbs,
    required this.label,
    this.showShadow = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // —— 绘制Smith圆和用户圆（用户圆心取abs） ——
    final circles = [
      _Circle(const Offset(0, 0), 1), // Smith,_Circle 是自定义的辅助类,原点单位圆
      _Circle(Offset(circleCenter.real.abs(), circleCenter.imaginary.abs()), circleRadius), // 圆心坐标取绝对值,，第二个是用户指定的稳定圆。
    ];

    //// 找出所有圆的最小/最大x,y范围（左、右、上、下界），为后续缩放适配用
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (var c in circles) {
      minX = minX < (c.center.dx - c.r) ? minX : (c.center.dx - c.r);
      maxX = maxX > (c.center.dx + c.r) ? maxX : (c.center.dx + c.r);
      minY = minY < (c.center.dy - c.r) ? minY : (c.center.dy - c.r);
      maxY = maxY > (c.center.dy + c.r) ? maxY : (c.center.dy + c.r);
    }
    double margin = 0.15 * (maxX - minX).abs();
    minX -= margin;
    maxX += margin;
    minY -= margin;
    maxY += margin;

    double dataW = maxX - minX, dataH = maxY - minY;
    double scale = 0.95 * (size.width < size.height ? size.width / dataW : size.height / dataH);
    double shiftX = -minX, shiftY = -minY;
    //这里是自动适配/自适应缩放，确保所有圆都能完整显示，并加一点“边距”。
    //scale 是数据空间→画布像素空间的缩放比例。

    //坐标变换辅助函数
    Offset toCanvas(double x, double y) {//数据平面上的点 (x, y) → 转成画布坐标系上的像素点 (px, py)。
      double px = (x + shiftX) * scale;
      double py = size.height - (y + shiftY) * scale;//注意y轴是反向的（上为0，下为最大），所以需要 size.height - ...。
      return Offset(px, py);
    }

    final smithCenter = toCanvas(0, 0);//单位圆圆心
    final smithRadius = scale * 1.0;//单位圆半径
    final userCenter = toCanvas(circleCenter.real.abs(), circleCenter.imaginary.abs());//用户圆心，绝对值
    final userRadius = scale * circleRadius;//用户半径，绝对值

    //画阴影区域,决定画哪一块区域是“安全区”
    if (showShadow) {
      _drawStableRegion(
        canvas,
        smithCenter,
        smithRadius,
        userCenter,
        userRadius,
        referenceAbs,
      );
    }// _drawStableRegion 会用Path布尔运算实现“交/并/差”区域填充，最终是黑白分明。

    // 画Smith单位圆,画出史密斯圆图的“本体”。
    final smithPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(smithCenter, smithRadius, smithPaint);

    // 画自定义圆,画你需要分析的那个稳定圆/噪声圆。
    final circlePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(userCenter, userRadius, circlePaint);

    // 画辅助坐标轴,横纵坐标辅助线，方便定位。
    final axisPaint = Paint()
      ..color = Colors.black.withOpacity(0.45)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, smithCenter.dy),
      Offset(size.width, smithCenter.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(smithCenter.dx, 0),
      Offset(smithCenter.dx, size.height),
      axisPaint,
    );

    // 画圆心点和标注,圆心加一个黑点，旁边写标签。
    final centerDotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(smithCenter, 3, centerDotPaint);
    canvas.drawCircle(userCenter, 3, centerDotPaint);
    // 标注文字
    _drawText(canvas, label, userCenter + const Offset(8, 6), 13, fontWeight: FontWeight.bold);
    _drawText(canvas, 'Smith Center', smithCenter + const Offset(10, 10), 12, fontWeight: FontWeight.w400);
  }

  // 在Smith圆图上高亮显示“稳定区/非稳定区”，即填充两个圆之间的特定区域。
  void _drawStableRegion(
      Canvas canvas,
      Offset smithCenter,
      double smithRadius,
      Offset userCenter,
      double userRadius,
      double referenceAbs,
      ) {
    final Path smithPath = Path()..addOval(Rect.fromCircle(center: smithCenter, radius: smithRadius));
    final Path userPath = Path()..addOval(Rect.fromCircle(center: userCenter, radius: userRadius));
    //构造Smith圆和用户圆的路径,用 Path 封装两个圆的位置和半径，后续用于布尔运算（求交、求差）。

    final Paint fillPaint = Paint()
      ..color = Colors.grey.withOpacity(0.28)
      ..style = PaintingStyle.fill;
    //半透明灰色填充，便于和其他图形叠加。

    final double d = (userCenter - smithCenter).distance;//两圆心的距离。
    final bool centerInStability = d < userRadius;//Smith圆心是否在用户圆内（如稳定圈包住了史密斯圆心）

    if (d >= smithRadius + userRadius) return;// 没有交集，不画
    if (userRadius >= d + smithRadius) return;// 完全包裹，也不画
    //如果两个圆完全不相交或者一个圆完全包住另一个，则不需要高亮，直接退出。

    //Path.combine(PathOperation.intersect, A, B)：A和B的交集区域
    //Path.combine(PathOperation.difference, A, B)：A减去B的区域
    //referenceAbs 表示 S 参数模值，用于区分“稳定区”和“不稳定区”是哪个区域。
    Path region;
    if (referenceAbs < 1) {
      if (centerInStability) {
        region = Path.combine(PathOperation.intersect, smithPath, userPath);
      } else {
        region = Path.combine(PathOperation.difference, smithPath, userPath);
      }
    } else {
      if (centerInStability) {
        region = Path.combine(PathOperation.difference, smithPath, userPath);
      } else {
        region = Path.combine(PathOperation.intersect, smithPath, userPath);
      }
    }
    canvas.drawPath(region, fillPaint);
  }

  //在canvas上写文字
  //自定义画文字的封装,参数含文字内容、偏移、字号、字体粗细。
  void _drawText(Canvas canvas, String text, Offset offset, double fontSize,
      {FontWeight fontWeight = FontWeight.normal}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  //直接返回 true，表示每次重绘都要重新画全部内容。
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

//方便把“圆心+半径”打包，减少参数传递复杂度。
//供主绘图函数用，不暴露给外部。
class _Circle {
  final Offset center;
  final double r;
  _Circle(this.center, this.r);
}
