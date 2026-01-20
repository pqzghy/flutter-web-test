import 'stability_circle_calculator.dart'; // CircleResult
import '../input_and_output_functions/utils.dart'; // ComplexFormatter工具类
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter/material.dart';
import 'package:equations/equations.dart';

class StabilityRegionDetector {
  final Complex s11, s12, s21, s22, delta;

  StabilityRegionDetector({
    required this.s11,
    required this.s12,
    required this.s21,
    required this.s22,
    required this.delta,
  });

  // 辅助函数：简化数字格式化
  String _fmt(double v) => ComplexFormatter.smartFormat(v);
  String _fmtC(Complex c, ComplexInputFormat f) => ComplexFormatter.universal(c, f);

  // 辅助函数：LaTeX 滚动容器
  Widget _texBlock(String latex) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Math.tex(
        latex,
        textStyle: const TextStyle(fontSize: 17, color: Colors.black87),
      ),
    );
  }

  List<Widget> detect(
      CircleResult circleResult, {
        double boundary = 1.0,
        ComplexInputFormat displayFormat = ComplexInputFormat.cartesian,
      }) {
    final widgets = <Widget>[];

    // ===============================================
    // 1. Source (Input) Stability Circle - 源端稳定性
    // ===============================================

    // 1.1 准备 Source 代入数据
    final s11_str = _fmtC(s11, displayFormat);
    final s22_conj_str = _fmtC(s22.conjugate(), displayFormat);
    final delta_str = _fmtC(delta, displayFormat);
    final cross_abs_str = _fmt((s12 * s21).abs());

    // 分子: S11 - Delta * S22*
    final num_source_tex = '$s11_str - $delta_str \\cdot $s22_conj_str';
    // 分母: |S11|^2 - |Delta|^2
    final den_source_tex = '|${_fmtC(s11, displayFormat)}|^2 - |${_fmtC(delta, displayFormat)}|^2';

    // 1.2 Source 判据逻辑
    // 修正：根据教科书 (Pozar)，Source Stability Circle (Input Plane)
    // 如果 |S11| < 1，则原点 (Gamma_S=0) 是稳定的。
    bool sourceOriginStableCheck = s11.modulus < 1.0;
    bool sourceCircleContainsOrigin = circleResult.sourceCenter.abs() < circleResult.sourceRadius;

    String sourceRegionText;
    if (sourceOriginStableCheck) {
      sourceRegionText = sourceCircleContainsOrigin
          ? "Since |S11| < 1 (Origin stable) & Origin INSIDE circle => Stable region is INSIDE."
          : "Since |S11| < 1 (Origin stable) & Origin OUTSIDE circle => Stable region is OUTSIDE.";
    } else {
      sourceRegionText = sourceCircleContainsOrigin
          ? "Since |S11| > 1 (Origin unstable) & Origin INSIDE circle => Stable region is OUTSIDE."
          : "Since |S11| > 1 (Origin unstable) & Origin OUTSIDE circle => Stable region is INSIDE.";
    }

    widgets.add(
      Column(
        key: const ValueKey('source'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Source (Input) Stability Circle:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo),
          ),
          const SizedBox(height: 8),
          const Text(
            'Analysis of the Input Plane (Γs).',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // --- Source Formulas ---
          const Text("Formulas:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          _texBlock(r'c_S = \frac{(S_{11} - \Delta S_{22}^*)^*}{|S_{11}|^2 - |\Delta|^2}'),
          _texBlock(r'r_S = \frac{|S_{12} S_{21}|}{\left| |S_{11}|^2 - |\Delta|^2 \right|}'),

          const SizedBox(height: 8),

          // --- Source Substitution ---
          const Text("Substitution:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          _texBlock(r'c_S = \frac{(' + num_source_tex + r')^*}{' + den_source_tex + r'}'),
          _texBlock(r'r_S = \frac{' + cross_abs_str + r'}{|' + den_source_tex + r'|}'),

          const SizedBox(height: 8),

          // --- Source Results ---
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Results:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                _texBlock(r'c_S = ' + _fmtC(circleResult.sourceCenter, displayFormat)),
                _texBlock(r'r_S = ' + _fmt(circleResult.sourceRadius)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // --- Source Stability Check ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Stability Region Logic:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                const SizedBox(height: 4),
                Text(sourceRegionText, style: const TextStyle(fontSize: 15, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );

    // 【重要修正】：移除了 Divider，防止索引错位导致 Load 部分消失
    // widgets.add(Divider...); <--- DELETED

    // =========================================================================
    // PART 2: Load (Output) Stability Circle Analysis
    // =========================================================================

    // 2.1 准备 Load 代入数据
    final s22_str = _fmtC(s22, displayFormat);
    final s11_conj_str = _fmtC(s11.conjugate(), displayFormat);
    // 分子: S22 - Delta * S11*
    final num_load_tex = '$s22_str - $delta_str \\cdot $s11_conj_str';
    // 分母: |S22|^2 - |Delta|^2
    final den_load_tex = '|${_fmtC(s22, displayFormat)}|^2 - |${_fmtC(delta, displayFormat)}|^2';

    // 2.2 Load 判据逻辑
    bool loadOriginStableCheck = s22.modulus < 1.0;
    bool loadCircleContainsOrigin = circleResult.loadCenter.abs() < circleResult.loadRadius;

    String loadRegionText;
    if (loadOriginStableCheck) {
      loadRegionText = loadCircleContainsOrigin
          ? "Since |S22| < 1 (Origin stable) & Origin INSIDE circle => Stable region is INSIDE."
          : "Since |S22| < 1 (Origin stable) & Origin OUTSIDE circle => Stable region is OUTSIDE.";
    } else {
      loadRegionText = loadCircleContainsOrigin
          ? "Since |S22| > 1 (Origin unstable) & Origin INSIDE circle => Stable region is OUTSIDE."
          : "Since |S22| > 1 (Origin unstable) & Origin OUTSIDE circle => Stable region is INSIDE.";
    }

    widgets.add(
      Column(
        key: const ValueKey('load'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Load (Output) Stability Circle:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo),
          ),
          const SizedBox(height: 8),
          const Text(
            'Analysis of the Output Plane (ΓL).',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // --- Load Formulas ---
          const Text("Formulas:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          _texBlock(r'c_L = \frac{(S_{22} - \Delta S_{11}^*)^*}{|S_{22}|^2 - |\Delta|^2}'),
          _texBlock(r'r_L = \frac{|S_{12} S_{21}|}{\left| |S_{22}|^2 - |\Delta|^2 \right|}'),

          const SizedBox(height: 8),

          // --- Load Substitution ---
          const Text("Substitution:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          _texBlock(r'c_L = \frac{(' + num_load_tex + r')^*}{' + den_load_tex + r'}'),
          _texBlock(r'r_L = \frac{' + cross_abs_str + r'}{|' + den_load_tex + r'|}'),

          const SizedBox(height: 8),

          // --- Load Results ---
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Results:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                _texBlock(r'c_L = ' + _fmtC(circleResult.loadCenter, displayFormat)),
                _texBlock(r'r_L = ' + _fmt(circleResult.loadRadius)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // --- Load Stability Check ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Stability Region Logic:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                const SizedBox(height: 4),
                Text(loadRegionText, style: const TextStyle(fontSize: 15, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );

    return widgets;
  }
}