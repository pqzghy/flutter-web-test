import 'package:flutter_math_fork/flutter_math.dart'; // 用于Latex公式渲染
import 'package:equations/equations.dart';

// 检查无条件稳定性的工具类（射频放大器常见判断）
// 原理参考稳定圆理论，判断放大器在给定源/负载平面是否无条件稳定
class UnconditionalStabilityChecker {
  // 成员变量定义：
  final Complex cs;  // 源稳定圆圆心（复数，反射系数坐标）
  final double rs;   // 源稳定圆半径（同上）
  final Complex cL;  // 负载稳定圆圆心
  final double rL;   // 负载稳定圆半径
  final Complex s11; // S11参数（输入端反射系数，复数）
  final Complex s22; // S22参数（输出端反射系数，复数）

  // 构造函数，全部为必填
  UnconditionalStabilityChecker({
    required this.cs,
    required this.rs,
    required this.cL,
    required this.rL,
    required this.s11,
    required this.s22,
  });

  // 核心判断函数，返回一个字符串结果（用英文描述结论，可直接显示到UI）
  String check() {
    // 计算负载侧 |CL - rL| 距离（实际为圆心到圆边的距离）
    double csDistance = (cs.abs() - rs).abs();
    double clDistance = (cL.abs() - rL).abs();
    // 分别计算 S11、S22 的模值
    double s11Abs = s11.abs();
    double s22Abs = s22.abs();

    // 第一种情况：负载平面无条件稳定（负载稳定圆在Smith圆外，且S11小于1）
    if (clDistance > 1 && s11Abs < 1) {
      return "|CL - rL| = ${clDistance.toStringAsFixed(4)} > 1 and |S11| = ${s11Abs.toStringAsFixed(4)} < 1 → Unconditionally Stable (Load plane)";
    }
    // 第二种情况：源平面无条件稳定（源稳定圆在Smith圆外，且S22小于1）
    else if (csDistance > 1 && s22Abs < 1) {
      return "|CS - rS| = ${csDistance.toStringAsFixed(4)} > 1 and |S22| = ${s22Abs.toStringAsFixed(4)} < 1 → Unconditionally Stable (Source plane)";
    }
    // 其余情况：都不满足，说明不是无条件稳定（需进一步分析）
    else {
      return "Conditionally Stable (Geometry check not satisfied)";
    }
  }
}
