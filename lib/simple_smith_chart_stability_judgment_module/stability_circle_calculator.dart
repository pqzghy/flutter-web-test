import 'package:equations/equations.dart';
import '../input_and_output_functions/utils.dart'; // 引入你的 utils.dart

class CircleResult {
  final Complex sourceCenter;
  final double sourceRadius;
  final Complex loadCenter;
  final double loadRadius;

  CircleResult(this.sourceCenter, this.sourceRadius, this.loadCenter, this.loadRadius);
}

class StabilityCircleCalculator {
  final Complex s11, s12, s21, s22;
  final Complex delta;
  final double z0;

  StabilityCircleCalculator({
    required this.s11,
    required this.s12,
    required this.s21,
    required this.s22,
    required this.delta,
    this.z0 = 50.0,
  });

  CircleResult calculate() {
    // 1. 输入端稳定圆 (Source Stability Circle)
    // 分母 D_S = |S11|^2 - |Delta|^2
    final denomIn = s11.modulus * s11.modulus - delta.modulus * delta.modulus;

    // 分子 N_S = (S11 - Delta * S22*)* // 【关键修正】：这里加了最外层的 .conjugate()
    final Complex numeratorSource = (s11 - delta * s22.conjugate()).conjugate();

    final Complex sourceCenter = Complex(
      numeratorSource.real / denomIn,
      numeratorSource.imaginary / denomIn,
    );

    // 计算输入端稳定圆半径 |S12 * S21| / denomIn
    final double sourceRadius = (s12 * s21).modulus / denomIn;


    // 2. 输出端稳定圆 (Load Stability Circle)
    // 分母 D_L = |S22|^2 - |Delta|^2
    final denomOut = s22.modulus * s22.modulus - delta.modulus * delta.modulus;

    // 分子 N_L = (S22 - Delta * S11*)* // 【关键修正】：这里加了最外层的 .conjugate()
    final Complex numeratorLoad = (s22 - delta * s11.conjugate()).conjugate();

    final Complex loadCenter = Complex(
      numeratorLoad.real / denomOut,
      numeratorLoad.imaginary / denomOut,
    );

    // 计算输出端稳定圆半径 |S12 * S21| / denomOut
    final double loadRadius = (s12 * s21).modulus / denomOut;

    return CircleResult(
      sourceCenter,
      sourceRadius.abs(), // 取绝对值防止因分母为负导致半径为负
      loadCenter,
      loadRadius.abs(),
    );
  }
}