import 'package:flutter/material.dart';
import 'package:equations/equations.dart';
import 'dart:math';
import '../input_and_output_functions/utils.dart';
import '../functional_components/fixed_input.dart';
import '../functional_components/menu_functions.dart';

// 史密斯图与稳定性判断相关模块
import '../simple_smith_chart_stability_judgment_module/smith_chart_widget.dart';
import '../simple_smith_chart_stability_judgment_module/stability_circle_calculator.dart';
import '../simple_smith_chart_stability_judgment_module/stability_region_detector.dart';

// 数学公式渲染库
import 'package:flutter_math_fork/flutter_math.dart';

// =================== StepPanel 数据结构 ===================
class StepPanel {
  final String title;
  final List<Widget> content;
  StepPanel({required this.title, required this.content});
}

// =================== AmplifierCalculator (核心计算逻辑类) ===================
class AmplifierCalculator {
  final Complex s11, s12, s21, s22;
  final double zs, zl;
  final double z0;

  AmplifierCalculator({
    required this.s11,
    required this.s12,
    required this.s21,
    required this.s22,
    required this.zs,
    required this.zl,
    this.z0 = 50.0,
  });

  // =================== NaN / Inf Protection ===================
  // 只做保护，不改任何原公式与数据流；遇到奇点就输出 NaN，让 UI 显示 Error 而不是崩溃。
  static const double _eps = 1e-12;

  bool _isBad(double x) => x.isNaN || x.isInfinite;

  // 安全显示 double：避免 smartFormat(NaN/Inf) 导致崩溃
  String _texNumSafe(double val) {
    if (val.isNaN) return r'\text{NaN}';
    if (val.isInfinite) return val.isNegative ? r'-\infty' : r'\infty';
    return ComplexFormatter.smartFormat(val, useLatex: true, precision: 4);
  }

  // 安全显示 Complex：避免 ComplexFormatter.latex 遇到 NaN/Inf 崩溃
  String _latexComplexSafe(Complex c, ComplexInputFormat fmt) {
    final r = c.real;
    final i = c.imaginary;
    if (_isBad(r) || _isBad(i)) return r'\text{NaN}';
    return ComplexFormatter.latex(c, fmt);
  }

  // 安全显示 Hybrid（用于 Γs/ΓL 等）
  String _latexHybridSafe(Complex c, {int precision = 4}) {
    final r = c.real;
    final i = c.imaginary;
    if (_isBad(r) || _isBad(i)) return r'\text{NaN}';
    return ComplexFormatter.latexHybrid(c, precision: precision);
  }

  // 安全复数除法：分母太小 => NaN（不改公式，只做定义域保护）
  Complex _safeDiv(Complex num, Complex den) {
    if (den.modulus < _eps) {
      return Complex(double.nan, double.nan);
    }
    final out = num / den;
    if (_isBad(out.real) || _isBad(out.imaginary)) {
      return Complex(double.nan, double.nan);
    }
    return out;
  }

  // 安全实数除法
  double _safeDivD(double num, double den) {
    if (den.abs() < _eps) return double.nan;
    final out = num / den;
    if (_isBad(out)) return double.nan;
    return out;
  }

  // 辅助函数：渲染可滚动的 LaTeX 公式
  Widget _texScroll(String latex) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Math.tex(
        latex,
        textStyle: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
    );
  }

  // 辅助函数：渲染普通文本
  Widget _text(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: Colors.black87,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          height: 1.4,
        ),
      ),
    );
  }

  // 辅助函数：智能格式化数值 —— 安全版
  String _texNum(double val) => _texNumSafe(val);

  // 辅助函数：生成标准化的结果行 (数值 + dB)
  String formatResultLine(String label, double val) {
    String dbPart;
    if (val.isNaN || val.isInfinite) {
      dbPart = r'\text{Error}';
    } else if (val <= 0) {
      dbPart = r'\text{Unstable } (<0)';
    } else {
      double db = 10 * log(val) / ln10;
      dbPart = _texNum(db) + r' \text{ dB}';
    }
    return label +
        ' = ' +
        _texNum(val) +
        r' \quad \left( ' +
        dbPart +
        r' \right)';
  }

  // 核心方法：构建计算步骤面板
  List<StepPanel> buildStepPanels(ComplexInputFormat displayFormat) {
    final panels = <StepPanel>[];

    // =========================================================
    // Step 1: Reflection Coefficients (Γs, ΓL)
    // =========================================================
    final zsStr = ComplexFormatter.smartFormat(zs);
    final zlStr = ComplexFormatter.smartFormat(zl);
    final z0Str = ComplexFormatter.smartFormat(z0);

    final gammaS = Complex(_safeDivD((zs - z0), (zs + z0)), 0);
    final gammaL = Complex(_safeDivD((zl - z0), (zl + z0)), 0);

    panels.add(
      StepPanel(
        title: '1. Reflection Coefficients (Γs, ΓL)',
        content: [
          _text('Calculate normalized reflection coefficients based on Zs, ZL, Z0.'),
          _texScroll(
            r'Z_0 = ' + z0Str + r', \ \ \ Z_s = ' + zsStr + r', \ \ \ Z_L = ' + zlStr,
          ),
          _text('Formula:', bold: true),
          _texScroll(r'\Gamma = \frac{Z - Z_0}{Z + Z_0}'),
          _text('Substitution:', bold: true),
          _texScroll(
            r'\Gamma_s = \frac{' +
                zsStr +
                '-' +
                z0Str +
                '}{' +
                zsStr +
                '+' +
                z0Str +
                r'} \;\Rightarrow\; ' +
                _latexHybridSafe(gammaS, precision: 4),
          ),
          _texScroll(
            r'\Gamma_L = \frac{' +
                zlStr +
                '-' +
                z0Str +
                '}{' +
                zlStr +
                '+' +
                z0Str +
                r'} \;\Rightarrow\; ' +
                _latexHybridSafe(gammaL, precision: 4),
          ),
          if ((zs + z0).abs() < _eps || (zl + z0).abs() < _eps)
            _text(
              '⚠ Warning: Z + Z0 ≈ 0, reflection coefficient is near a singularity (may become NaN/∞).',
              bold: true,
            ),
        ],
      ),
    );

    // =========================================================
    // Step 2: Determinant (Δ)
    // =========================================================
    final delta = s11 * s22 - s12 * s21;

    panels.add(
      StepPanel(
        title: '2. Determinant (Δ)',
        content: [
          _text('Formula:', bold: true),
          _texScroll(r'\Delta = S_{11} S_{22} - S_{12} S_{21}'),
          _text('Substitution:', bold: true),
          _texScroll(r'\Delta = (' +
              _latexComplexSafe(s11, displayFormat) +
              r')(' +
              _latexComplexSafe(s22, displayFormat) +
              r') - ' +
              r'(' +
              _latexComplexSafe(s12, displayFormat) +
              r')(' +
              _latexComplexSafe(s21, displayFormat) +
              r')'),
          const Divider(),
          _text('Result:', bold: true),
          _texScroll(r'\Delta = ' + _latexComplexSafe(delta, displayFormat)),
          _texScroll(r'|\Delta| = ' + _texNum(delta.modulus)),
        ],
      ),
    );

    // =========================================================
    // Step 3: Input/Output Reflection (Γin, Γout)
    // =========================================================
    final numeratorIn = s12 * s21 * gammaL;
    final denominatorIn = Complex(1, 0) - s22 * gammaL;
    final gammaIn = s11 + _safeDiv(numeratorIn, denominatorIn);

    final numeratorOut = s12 * s21 * gammaS;
    final denominatorOut = Complex(1, 0) - s11 * gammaS;
    final gammaOut = s22 + _safeDiv(numeratorOut, denominatorOut);

    final bool singularIn = denominatorIn.modulus < _eps;
    final bool singularOut = denominatorOut.modulus < _eps;

    panels.add(
      StepPanel(
        title: '3. Input/Output Reflection (Γin, Γout)',
        content: [
          _text('Formula:', bold: true),
          _texScroll(
              r'\Gamma_{in} = S_{11} + \frac{S_{12} S_{21} \Gamma_L}{1 - S_{22} \Gamma_L}'),
          _text('Substitution:', bold: true),
          _texScroll(r'\Gamma_{in} = ' +
              _latexComplexSafe(s11, displayFormat) +
              r' + \frac{(' +
              _latexComplexSafe(s12, displayFormat) +
              r')(' +
              _latexComplexSafe(s21, displayFormat) +
              r')(' +
              _latexComplexSafe(gammaL, displayFormat) +
              r')}' +
              r'{1 - (' +
              _latexComplexSafe(s22, displayFormat) +
              r')(' +
              _latexComplexSafe(gammaL, displayFormat) +
              r')}'),
          if (singularIn)
            _text(
              '⚠ Warning: (1 - S22·ΓL) ≈ 0, Γin is near a singularity (may become NaN/∞).',
              bold: true,
            ),
          if (singularOut)
            _text(
              '⚠ Warning: (1 - S11·ΓS) ≈ 0, Γout is near a singularity (may become NaN/∞).',
              bold: true,
            ),
          const Divider(),
          _text('Result:', bold: true),
          _texScroll(r'\Gamma_{in} = ' + _latexComplexSafe(gammaIn, displayFormat)),
          _texScroll(r'\Gamma_{out} = ' + _latexComplexSafe(gammaOut, displayFormat)),
        ],
      ),
    );

    // =========================================================
    // Step 4: Power Gains (Gt, Gp, Ga) - 教学模式
    // =========================================================
    final double gsMagSq = pow(gammaS.modulus, 2).toDouble();
    final double glMagSq = pow(gammaL.modulus, 2).toDouble();
    final double s21MagSq = pow(s21.modulus, 2).toDouble();
    final double ginMagSq = pow(gammaIn.modulus, 2).toDouble();
    final double goutMagSq = pow(gammaOut.modulus, 2).toDouble();

    final double denom_In_S =
    pow((Complex(1, 0) - gammaIn * gammaS).modulus, 2).toDouble();
    final double denom_22_L =
    pow((Complex(1, 0) - s22 * gammaL).modulus, 2).toDouble();
    final double denom_11_S =
    pow((Complex(1, 0) - s11 * gammaS).modulus, 2).toDouble();

    final double gt_term1_num = 1.0 - gsMagSq;
    final double gt_term1 = _safeDivD(gt_term1_num, denom_In_S);
    final double gt_term3_num = 1.0 - glMagSq;
    final double gt_term3 = _safeDivD(gt_term3_num, denom_22_L);
    final double gt = gt_term1 * s21MagSq * gt_term3;

    final double gp_term1 = _safeDivD(1.0, (1.0 - ginMagSq));
    final double gp = gp_term1 * s21MagSq * gt_term3;

    final double ga_term1 = _safeDivD(gt_term1_num, denom_11_S);
    final double ga_term3 = _safeDivD(1.0, (1.0 - goutMagSq));
    final double ga = ga_term1 * s21MagSq * ga_term3;

    panels.add(
      StepPanel(
        title: '4. Power Gains (Gt, Gp, Ga)',
        content: [
          _text(
              'To calculate gains, we break down the formula into three parts: Input Mismatch, Device Gain, and Output Mismatch.'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text('Known Values (Pre-calculated):', bold: true),
                _texScroll(r'|\Gamma_S|^2 = ' +
                    _texNum(gsMagSq) +
                    r', \quad |\Gamma_L|^2 = ' +
                    _texNum(glMagSq)),
                _texScroll(r'|S_{21}|^2 = ' + _texNum(s21MagSq)),
                _texScroll(r'|1 - \Gamma_{in}\Gamma_S|^2 = ' + _texNum(denom_In_S)),
                _texScroll(r'|1 - S_{22}\Gamma_L|^2 = ' + _texNum(denom_22_L)),
                _texScroll(r'|1 - S_{11}\Gamma_S|^2 = ' + _texNum(denom_11_S)),
                _texScroll(r'|1 - \Gamma_{out}|^2 = ' + _texNum(1.0 - goutMagSq)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _text('1. Transducer Power Gain (Gt)', bold: true),
          _texScroll(
              r'G_t = \underbrace{\frac{1 - |\Gamma_S|^2}{|1 - \Gamma_{in}\Gamma_S|^2}}_{\text{Input}} \cdot \underbrace{|S_{21}|^2}_{\text{Device}} \cdot \underbrace{\frac{1 - |\Gamma_L|^2}{|1 - S_{22}\Gamma_L|^2}}_{\text{Output}}'),
          _text('Substitution:', bold: true),
          _texScroll(r'G_t \approx \left( \frac{1 - ' +
              _texNum(gsMagSq) +
              r'}{' +
              _texNum(denom_In_S) +
              r'} \right) \cdot ' +
              _texNum(s21MagSq) +
              r' \cdot \left( \frac{1 - ' +
              _texNum(glMagSq) +
              r'}{' +
              _texNum(denom_22_L) +
              r'} \right)'),
          _texScroll(r'\Rightarrow G_t \approx (' +
              _texNum(gt_term1) +
              r') \cdot (' +
              _texNum(s21MagSq) +
              r') \cdot (' +
              _texNum(gt_term3) +
              r')'),
          _text('Result:', bold: true),
          _texScroll(formatResultLine('G_t', gt)),
          const Divider(),

          _text('2. Operating Power Gain (Gp)', bold: true),
          _texScroll(
              r'G_p = \frac{1}{1 - |\Gamma_{in}|^2} \cdot |S_{21}|^2 \cdot \frac{1 - |\Gamma_L|^2}{|1 - S_{22}\Gamma_L|^2}'),
          _text('Substitution:', bold: true),
          _texScroll(r'G_p \approx \left( \frac{1}{1 - ' +
              _texNum(ginMagSq) +
              r'} \right) \cdot ' +
              _texNum(s21MagSq) +
              r' \cdot (' +
              _texNum(gt_term3) +
              r')'),
          _text('Result:', bold: true),
          _texScroll(formatResultLine('G_p', gp)),
          const Divider(),

          _text('3. Available Power Gain (Ga)', bold: true),
          _texScroll(
              r'G_a = \frac{1 - |\Gamma_S|^2}{|1 - S_{11}\Gamma_S|^2} \cdot |S_{21}|^2 \cdot \frac{1}{1 - |\Gamma_{out}|^2}'),
          _text('Substitution:', bold: true),
          _texScroll(r'G_a \approx (' +
              _texNum(ga_term1) +
              r') \cdot ' +
              _texNum(s21MagSq) +
              r' \cdot \left( \frac{1}{1 - ' +
              _texNum(goutMagSq) +
              r'} \right)'),
          _text('Result:', bold: true),
          _texScroll(formatResultLine('G_a', ga)),
        ],
      ),
    );

    // =========================================================
    // Step 5: Stability Analysis (K, Delta, Mu, Mu') - Ultimate Version
    // =========================================================
    const double epsilon = 1e-9;
    final bool isUnilateral = (s12.modulus < epsilon) || (s21.modulus < epsilon);

    if (isUnilateral) {
      final double s11Mag = s11.modulus;
      final double s22Mag = s22.modulus;
      final bool isStableUni = (s11Mag < 1.0) && (s22Mag < 1.0);

      panels.add(
        StepPanel(
          title: '5. Stability Analysis (Unilateral Case)',
          content: [
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blue[50],
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _text(
                      r'Unilateral Condition Detected (|S12| ≈ 0 or |S21| ≈ 0). Rollett Factor (K) is undefined.',
                      bold: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _text(
              'Since there is no feedback (S12 = 0), stability is determined solely by checking if input/output ports are passive.',
            ),
            _text('Conditions for Unconditional Stability:', bold: true),
            _texScroll(r'|S_{11}| < 1 \quad \text{and} \quad |S_{22}| < 1'),
            const Divider(),
            _text('Substitution (Value Replacement):', bold: true),
            _texScroll(r'|S_{11}| = ' + _texNum(s11Mag)),
            _texScroll(r'|S_{22}| = ' + _texNum(s22Mag)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isStableUni ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isStableUni ? Colors.green : Colors.deepOrange,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isStableUni ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: isStableUni ? Colors.green[700] : Colors.deepOrange,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isStableUni ? "Unconditionally Stable" : "Potentially Unstable",
                          style: TextStyle(
                            color: isStableUni ? Colors.green[800] : Colors.deepOrange[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isStableUni
                              ? "|S11| < 1 and |S22| < 1 satisfied."
                              : "Input or Output port has negative resistance (|Sxx| > 1).",
                          style: TextStyle(
                            color: isStableUni ? Colors.green[700] : Colors.deepOrange[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      final double s11MagSq = pow(s11.modulus, 2).toDouble();
      final double s22MagSq = pow(s22.modulus, 2).toDouble();
      final double deltaMagSq = pow((s11 * s22 - s12 * s21).modulus, 2).toDouble();
      final double denomK_val = 2.0 * s12.modulus * s21.modulus;
      final double numeratorK_val = 1.0 - s11MagSq - s22MagSq + deltaMagSq;
      final double k = _safeDivD(numeratorK_val, denomK_val);

      final double muNumerator = 1.0 - s11MagSq;
      final term1MuComplex = s22 - (s11 * s22 - s12 * s21) * s11.conjugate();
      final double term1Mu = term1MuComplex.modulus;
      final double term2_stability = s12.modulus * s21.modulus;
      final double mu = _safeDivD(muNumerator, (term1Mu + term2_stability));

      final double muPrimeNumerator = 1.0 - s22MagSq;
      final term1MuPrimeComplex = s11 - (s11 * s22 - s12 * s21) * s22.conjugate();
      final double term1MuPrime = term1MuPrimeComplex.modulus;
      final double muPrime = _safeDivD(muPrimeNumerator, (term1MuPrime + term2_stability));

      final isUnconditionallyStable = (mu > 1);

      panels.add(
        StepPanel(
          title: '5. Stability Analysis (K, Δ, μ)',
          content: [
            _text('Stability criteria ensure the amplifier does not oscillate.'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _text('Known Values for Stability:', bold: true),
                  _texScroll(r'|S_{11}|^2 = ' +
                      _texNum(s11MagSq) +
                      r', \quad |S_{22}|^2 = ' +
                      _texNum(s22MagSq)),
                  _texScroll(r'|\Delta|^2 = ' +
                      _texNum(deltaMagSq) +
                      r', \quad 2|S_{12}S_{21}| = ' +
                      _texNum(denomK_val)),
                  _texScroll(r'|S_{22} - \Delta S_{11}^*| = ' +
                      _texNum(term1Mu) +
                      r', \quad |S_{12}S_{21}| = ' +
                      _texNum(term2_stability)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _text('1. Rollett Factor (K)', bold: true),
            _texScroll(
                r'K = \frac{1 - |S_{11}|^2 - |S_{22}|^2 + |\Delta|^2}{2|S_{12} S_{21}|}'),
            _text('Result:', bold: true),
            _texScroll(r'K = \mathbf{' + _texNum(k) + r'}'),
            const Divider(),

            _text('2. Geometric Stability Factor (μ)', bold: true),
            _texScroll(
                r'\mu = \frac{1 - |S_{11}|^2}{|S_{22} - \Delta S_{11}^*| + |S_{12} S_{21}|}'),
            _text('Result:', bold: true),
            _texScroll(r'\mu = \mathbf{' + _texNum(mu) + r'}'),
            const Divider(),

            _text('3. Geometric Stability Factor (μ\')', bold: true),
            _texScroll(
                r"\mu' = \frac{1 - |S_{22}|^2}{|S_{11} - \Delta S_{22}^*| + |S_{12} S_{21}|}"),
            _text('Result:', bold: true),
            _texScroll(r"\mu' = \mathbf{" + _texNum(muPrime) + r"}"),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnconditionallyStable ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isUnconditionallyStable ? Colors.green : Colors.deepOrange,
                    width: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    isUnconditionallyStable ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: isUnconditionallyStable ? Colors.green[700] : Colors.deepOrange,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUnconditionallyStable ? "Unconditionally Stable" : "Potentially Unstable",
                          style: TextStyle(
                            color: isUnconditionallyStable ? Colors.green[800] : Colors.deepOrange[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isUnconditionallyStable ? "Satisfies μ > 1." : "μ < 1. Check Stability Circles.",
                          style: TextStyle(
                            color: isUnconditionallyStable ? Colors.green[700] : Colors.deepOrange[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return panels;
  }
}

// =================== 示例数据结构 ===================
class ExamplePreset {
  final String name;

  // scalar
  final String freqGHz;
  final String z0;
  final String zs;
  final String zl;

  // S-params (mag/angle in DEG, matches polarDegree controllers)
  final String s11Mag, s11Ang;
  final String s12Mag, s12Ang;
  final String s21Mag, s21Ang;
  final String s22Mag, s22Ang;

  const ExamplePreset({
    required this.name,
    required this.freqGHz,
    required this.z0,
    required this.zs,
    required this.zl,
    required this.s11Mag,
    required this.s11Ang,
    required this.s12Mag,
    required this.s12Ang,
    required this.s21Mag,
    required this.s21Ang,
    required this.s22Mag,
    required this.s22Ang,
  });
}

// =================== 主页面 (UI Shell) ===================
class AmplifierHomePage extends StatefulWidget {
  const AmplifierHomePage({super.key});

  @override
  State<AmplifierHomePage> createState() => _AmplifierHomePageState();
}

class _AmplifierHomePageState extends State<AmplifierHomePage> {
  final _formKey = GlobalKey<FormState>();

  // 默认值
  final freqController = TextEditingController(text: '9');
  final s11C1 = TextEditingController(text: '0.89');
  final s11C2 = TextEditingController(text: '-60.73');
  final s12C1 = TextEditingController(text: '0.02');
  final s12C2 = TextEditingController(text: '62.45');
  final s21C1 = TextEditingController(text: '3.12');
  final s21C2 = TextEditingController(text: '123.76');
  final s22C1 = TextEditingController(text: '0.78');
  final s22C2 = TextEditingController(text: '-27.50');
  final zsC = TextEditingController(text: '50');
  final zlC = TextEditingController(text: '50');
  final z0C = TextEditingController(text: '50');

  ComplexInputFormat _currentFormat = ComplexInputFormat.polarDegree;

  List<bool> _expandedList = [];
  List<StepPanel> _stepPanels = [];

  // 稳定性圆绘图相关状态
  bool _sourceRegionExpanded = false;
  bool _loadRegionExpanded = false;
  Widget? _sourceRegionWidget;
  Widget? _loadRegionWidget;
  Complex? sourceCenter, loadCenter;
  double? sourceRadius, loadRadius;
  double? s22Abs, s11Abs;
  bool isPotentiallyUnstableSource = false;
  bool isPotentiallyUnstableLoad = false;

  // 与 AmplifierCalculator 同步的 eps（仅用于 UI 绘图保护）
  static const double _eps = 1e-12;

  double _safeDivD(double num, double den) {
    if (den.abs() < _eps) return double.nan;
    final out = num / den;
    if (out.isNaN || out.isInfinite) return double.nan;
    return out;
  }

  // =================== 示例列表（ 4-1 / 4-2） ===================
  late final List<ExamplePreset> _examples = [
    // Example 4-1 (book)
    const ExamplePreset(
      name: 'Example 4-1 (MESFET, 9 GHz)',
      freqGHz: '9',
      z0: '50',
      zs: '50',
      zl: '50',
      s11Mag: '0.894',
      s11Ang: '-60.6',
      s12Mag: '0.02',
      s12Ang: '62.4',
      s21Mag: '3.122',
      s21Ang: '123.6',
      s22Mag: '0.781',
      s22Ang: '-27.6',
    ),

    // Example 4-2 (book)
    const ExamplePreset(
      name: 'Example 4-2 (Transistor, 9 GHz)',
      freqGHz: '9',
      z0: '50',
      zs: '50',
      zl: '50',
      s11Mag: '0.65',
      s11Ang: '-95',
      s12Mag: '0.035',
      s12Ang: '40',
      s21Mag: '5',
      s21Ang: '115',
      s22Mag: '0.8',
      s22Ang: '-35',
    ),

    // Unilateral test (skip circles/regions)
    const ExamplePreset(
      name: 'Unilateral Test (S12 ≈ 0)',
      freqGHz: '9',
      z0: '50',
      zs: '50',
      zl: '50',
      s11Mag: '0.75',
      s11Ang: '-30',
      s12Mag: '0.0',
      s12Ang: '0',
      s21Mag: '2.5',
      s21Ang: '90',
      s22Mag: '0.6',
      s22Ang: '-20',
    ),

    // Γin singularity-ish: make ΓL ~ 1 by huge ZL and S22 ~ 1∠0
    const ExamplePreset(
      name: 'Singularity Test (1 - S22·ΓL ≈ 0)',
      freqGHz: '9',
      z0: '50',
      zs: '50',
      zl: '1000000000', // huge -> ΓL ~ 1
      s11Mag: '0.5',
      s11Ang: '-10',
      s12Mag: '0.05',
      s12Ang: '30',
      s21Mag: '2',
      s21Ang: '60',
      s22Mag: '1.0',
      s22Ang: '0',
    ),

    // Reflection coefficient singularity: Zs = -Z0 => denom ~ 0
    const ExamplePreset(
      name: 'Z Singularity Test (Zs + Z0 ≈ 0)',
      freqGHz: '9',
      z0: '50',
      zs: '-50', // Zs + Z0 = 0
      zl: '50',
      s11Mag: '0.8',
      s11Ang: '-45',
      s12Mag: '0.08',
      s12Ang: '20',
      s21Mag: '3.2',
      s21Ang: '110',
      s22Mag: '0.7',
      s22Ang: '-10',
    ),

    // A more “aggressive feedback” case (often μ < 1)
    const ExamplePreset(
      name: 'Potentially Unstable (strong feedback)',
      freqGHz: '9',
      z0: '50',
      zs: '50',
      zl: '50',
      s11Mag: '0.92',
      s11Ang: '-150',
      s12Mag: '0.18',
      s12Ang: '20',
      s21Mag: '1.6',
      s21Ang: '80',
      s22Mag: '0.9',
      s22Ang: '-120',
    ),
  ];

  int _exampleIndex = 0;

  void _applyExample(ExamplePreset ex) {
    // 示例统一按 Polar(deg) 写入（避免格式错配导致解析异常）
    _currentFormat = ComplexInputFormat.polarDegree;

    freqController.text = ex.freqGHz;
    z0C.text = ex.z0;
    zsC.text = ex.zs;
    zlC.text = ex.zl;

    s11C1.text = ex.s11Mag;
    s11C2.text = ex.s11Ang;

    s12C1.text = ex.s12Mag;
    s12C2.text = ex.s12Ang;

    s21C1.text = ex.s21Mag;
    s21C2.text = ex.s21Ang;

    s22C1.text = ex.s22Mag;
    s22C2.text = ex.s22Ang;
  }

  void _nextExampleAndRecalculate() {
    setState(() {
      _exampleIndex = (_exampleIndex + 1) % _examples.length;

      // 先清空旧状态，避免“旧面板长度”与新面板长度瞬间错配
      _stepPanels = [];
      _expandedList = [];

      _sourceRegionExpanded = false;
      _loadRegionExpanded = false;
      _sourceRegionWidget = null;
      _loadRegionWidget = null;

      sourceCenter = null;
      sourceRadius = null;
      loadCenter = null;
      loadRadius = null;
      s22Abs = null;
      s11Abs = null;

      isPotentiallyUnstableSource = false;
      isPotentiallyUnstableLoad = false;

      _applyExample(_examples[_exampleIndex]);
    });

    // 直接算（不弹 SnackBar）
    calculate();
  }

  String _joinInput(TextEditingController c1, TextEditingController c2) {
    String a = c1.text.trim();
    String b = c2.text.trim();
    if (a.isEmpty) a = '0';
    if (b.isEmpty) b = '0';

    switch (_currentFormat) {
      case ComplexInputFormat.cartesian:
        return ComplexInputUtil.joinForParse(a, b);
      case ComplexInputFormat.polarDegree:
        return '$a∠$b°';
      case ComplexInputFormat.polarRadian:
        return '$a∠${b}rad';
    }
  }

  void switchAllFormat(ComplexInputFormat newFormat) {
    setState(() {
      final s11 = ComplexParser.parseUniversal(_joinInput(s11C1, s11C2), _currentFormat);
      final s12 = ComplexParser.parseUniversal(_joinInput(s12C1, s12C2), _currentFormat);
      final s21 = ComplexParser.parseUniversal(_joinInput(s21C1, s21C2), _currentFormat);
      final s22 = ComplexParser.parseUniversal(_joinInput(s22C1, s22C2), _currentFormat);

      void updateControllers(Complex c, TextEditingController c1, TextEditingController c2) {
        if (newFormat == ComplexInputFormat.cartesian) {
          c1.text = ComplexFormatter.smartFormat(c.real, useScientific: false, precision: 6);
          c2.text = ComplexFormatter.smartFormat(c.imaginary, useScientific: false, precision: 6);
        } else {
          c1.text = ComplexFormatter.smartFormat(c.modulus, useScientific: false, precision: 6);
          double angle = (newFormat == ComplexInputFormat.polarDegree)
              ? c.phase() * 180 / pi
              : c.phase();
          c2.text = ComplexFormatter.smartFormat(angle, useScientific: false, precision: 6);
        }
      }

      updateControllers(s11, s11C1, s11C2);
      updateControllers(s12, s12C1, s12C2);
      updateControllers(s21, s21C1, s21C2);
      updateControllers(s22, s22C1, s22C2);

      _currentFormat = newFormat;

      if (_stepPanels.isNotEmpty) {
        calculate();
      }
    });
  }

  void calculate() {
    if (!_formKey.currentState!.validate()) return;

    final s11 = ComplexParser.parseUniversal(_joinInput(s11C1, s11C2), _currentFormat);
    final s12 = ComplexParser.parseUniversal(_joinInput(s12C1, s12C2), _currentFormat);
    final s21 = ComplexParser.parseUniversal(_joinInput(s21C1, s21C2), _currentFormat);
    final s22 = ComplexParser.parseUniversal(_joinInput(s22C1, s22C2), _currentFormat);

    final z0 = double.tryParse(z0C.text) ?? 50.0;
    final zs = double.tryParse(zsC.text) ?? 50.0;
    final zl = double.tryParse(zlC.text) ?? 50.0;

    // =========================================================
    // Unilateral detection (UI-level): 用于“彻底跳过 circle/region”
    // =========================================================
    const double unilateralEps = 1e-9;
    final bool isUnilateral = (s12.modulus < unilateralEps || s21.modulus < unilateralEps);

    final amplifier = AmplifierCalculator(
      s11: s11,
      s12: s12,
      s21: s21,
      s22: s22,
      zs: zs,
      zl: zl,
      z0: z0,
    );

    final stepPanels = amplifier.buildStepPanels(_currentFormat);

    // 关键：每次重算都重置 expandedList，彻底避免 “Unexpected null value”/越界类错误
    _expandedList = List.generate(stepPanels.length, (_) => false);

    if (isUnilateral) {
      setState(() {
        _stepPanels = stepPanels;

        _sourceRegionExpanded = false;
        _loadRegionExpanded = false;
        _sourceRegionWidget = null;
        _loadRegionWidget = null;

        sourceCenter = null;
        sourceRadius = null;
        loadCenter = null;
        loadRadius = null;
        s22Abs = null;
        s11Abs = null;

        isPotentiallyUnstableSource = false;
        isPotentiallyUnstableLoad = false;
      });
      return;
    }

    final delta = s11 * s22 - s12 * s21;
    final stability = StabilityCircleCalculator(
      s11: s11,
      s12: s12,
      s21: s21,
      s22: s22,
      delta: delta,
      z0: z0,
    ).calculate();

    sourceCenter = stability.sourceCenter;
    sourceRadius = stability.sourceRadius;
    loadCenter = stability.loadCenter;
    loadRadius = stability.loadRadius;
    s22Abs = s22.modulus;
    s11Abs = s11.modulus;

    final double s11MagSq = pow(s11.modulus, 2).toDouble();
    final term1 = (s22 - delta * s11.conjugate()).modulus;
    final double term2 = s12.modulus * s21.modulus;
    final double mu = _safeDivD((1.0 - s11MagSq), (term1 + term2));

    bool isUnconditionallyStable = (mu > 1);
    isPotentiallyUnstableSource = !isUnconditionallyStable;
    isPotentiallyUnstableLoad = !isUnconditionallyStable;

    final region = StabilityRegionDetector(
      s11: s11,
      s12: s12,
      s21: s21,
      s22: s22,
      delta: delta,
    ).detect(stability, displayFormat: _currentFormat);

    Widget? srcWidget = region.isNotEmpty ? region[0] : null;
    Widget? loadWidget = region.length > 1 ? region[1] : null;

    setState(() {
      _stepPanels = stepPanels;
      _sourceRegionExpanded = false;
      _loadRegionExpanded = false;

      final bool canDrawSource = isPotentiallyUnstableSource &&
          sourceCenter != null &&
          sourceRadius != null &&
          !(sourceRadius!.isNaN || sourceRadius!.isInfinite);

      final bool canDrawLoad = isPotentiallyUnstableLoad &&
          loadCenter != null &&
          loadRadius != null &&
          !(loadRadius!.isNaN || loadRadius!.isInfinite);

      _sourceRegionWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (srcWidget != null) srcWidget,
          if (canDrawSource)
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: SmithChartWidget(
                circleCenter: sourceCenter!,
                circleRadius: sourceRadius!,
                referenceAbs: s22Abs!,
                isPotentiallyUnstable: isPotentiallyUnstableSource,
                label: "Source Stability Circle",
              ),
            ),
          if (isPotentiallyUnstableSource && !canDrawSource)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(
                "⚠ Source circle cannot be drawn (radius is NaN/∞).",
                style: TextStyle(color: Colors.deepOrange[700], fontSize: 13),
              ),
            ),
        ],
      );

      _loadRegionWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loadWidget != null) loadWidget,
          if (canDrawLoad)
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: SmithChartWidget(
                circleCenter: loadCenter!,
                circleRadius: loadRadius!,
                referenceAbs: s11Abs!,
                isPotentiallyUnstable: isPotentiallyUnstableLoad,
                label: "Load Stability Circle",
              ),
            ),
          if (isPotentiallyUnstableLoad && !canDrawLoad)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(
                "⚠ Load circle cannot be drawn (radius is NaN/∞).",
                style: TextStyle(color: Colors.deepOrange[700], fontSize: 13),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildFormatBtn(String text, ComplexInputFormat fmt) {
    bool isSelected = _currentFormat == fmt;
    return ElevatedButton(
      onPressed: () => switchAllFormat(fmt),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.deepPurple : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildScalarInput(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      validator: commonValidator,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        isDense: true,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    setState(() {
      _exampleIndex = 0;
      _applyExample(_examples[_exampleIndex]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ex = _examples[_exampleIndex];

    return CommonScaffold(
      title: 'Amplifier Full Flow Calculator',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =================== Format Switch ===================
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFormatBtn('Cartesian (a+bj)', ComplexInputFormat.cartesian),
                    const SizedBox(width: 8),
                    _buildFormatBtn('Polar (deg)', ComplexInputFormat.polarDegree),
                    const SizedBox(width: 8),
                    _buildFormatBtn('Polar (rad)', ComplexInputFormat.polarRadian),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // =================== Example Switch (ONE button) ===================
              Card(
                elevation: 0,
                color: Colors.grey[50],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Current Example: ${ex.name}  (${_exampleIndex + 1}/${_examples.length})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _nextExampleAndRecalculate,
                        icon: const Icon(Icons.loop),
                        label: const Text('Next Example'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // =================== Inputs ===================
              ComplexInputRow(
                format: _currentFormat,
                ctrl1: s11C1,
                ctrl2: s11C2,
                paramName: 'S11',
                validator: commonValidator,
              ),
              ComplexInputRow(
                format: _currentFormat,
                ctrl1: s12C1,
                ctrl2: s12C2,
                paramName: 'S12',
                validator: commonValidator,
              ),
              ComplexInputRow(
                format: _currentFormat,
                ctrl1: s21C1,
                ctrl2: s21C2,
                paramName: 'S21',
                validator: commonValidator,
              ),
              ComplexInputRow(
                format: _currentFormat,
                ctrl1: s22C1,
                ctrl2: s22C2,
                paramName: 'S22',
                validator: commonValidator,
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: _buildScalarInput(freqController, 'Freq (GHz)')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildScalarInput(z0C, 'Z0 (Ω)')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildScalarInput(zsC, 'Zs (Source)')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildScalarInput(zlC, 'Zl (Load)')),
                ],
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: calculate,
                  icon: const Icon(Icons.calculate),
                  label: const Text('Calculate All Parameters', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // =================== Step Panels ===================
              if (_stepPanels.isNotEmpty)
                ExpansionPanelList(
                  expansionCallback: (panelIndex, isExpanded) {
                    setState(() {
                      if (panelIndex >= 0 && panelIndex < _expandedList.length) {
                        _expandedList[panelIndex] = !_expandedList[panelIndex];
                      }
                    });
                  },
                  children: _stepPanels.asMap().entries.map((entry) {
                    final idx = entry.key;
                    return ExpansionPanel(
                      headerBuilder: (context, isExpanded) => ListTile(
                        title: Text(
                          entry.value.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isExpanded ? Colors.deepPurple : Colors.black87,
                          ),
                        ),
                      ),
                      body: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: entry.value.content,
                        ),
                      ),
                      isExpanded: (idx < _expandedList.length) ? _expandedList[idx] : false,
                      canTapOnHeader: true,
                    );
                  }).toList(),
                  elevation: 1,
                ),

              // =================== Stability Regions ===================
              if (_sourceRegionWidget != null || _loadRegionWidget != null) ...[
                const SizedBox(height: 10),
                ExpansionPanelList(
                  expansionCallback: (panelIndex, isExpanded) {
                    setState(() {
                      if (panelIndex == 0) _sourceRegionExpanded = !_sourceRegionExpanded;
                      if (panelIndex == 1) _loadRegionExpanded = !_loadRegionExpanded;
                    });
                  },
                  children: [
                    ExpansionPanel(
                      headerBuilder: (context, isExpanded) => ListTile(
                        leading: Icon(
                          Icons.warning_amber_rounded,
                          color: isPotentiallyUnstableSource ? Colors.orange : Colors.green,
                        ),
                        title: Text(
                          'Source Stability Analysis',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPotentiallyUnstableSource ? Colors.deepOrange : Colors.black87,
                          ),
                        ),
                      ),
                      body: _sourceRegionExpanded && _sourceRegionWidget != null
                          ? Padding(padding: const EdgeInsets.all(16), child: _sourceRegionWidget!)
                          : const SizedBox.shrink(),
                      isExpanded: _sourceRegionExpanded,
                      canTapOnHeader: true,
                    ),
                    ExpansionPanel(
                      headerBuilder: (context, isExpanded) => ListTile(
                        leading: Icon(
                          Icons.warning_amber_rounded,
                          color: isPotentiallyUnstableLoad ? Colors.orange : Colors.green,
                        ),
                        title: Text(
                          'Load Stability Analysis',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPotentiallyUnstableLoad ? Colors.deepOrange : Colors.black87,
                          ),
                        ),
                      ),
                      body: _loadRegionExpanded && _loadRegionWidget != null
                          ? Padding(padding: const EdgeInsets.all(16), child: _loadRegionWidget!)
                          : const SizedBox.shrink(),
                      isExpanded: _loadRegionExpanded,
                      canTapOnHeader: true,
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
