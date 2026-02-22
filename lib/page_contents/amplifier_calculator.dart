import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:equations/equations.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../input_and_output_functions/utils.dart';
import '../functional_components/fixed_input.dart';
import '../functional_components/menu_functions.dart';
import '../simple_smith_chart_stability_judgment_module/smith_chart_widget.dart';
import '../simple_smith_chart_stability_judgment_module/stability_circle_calculator.dart';
import '../simple_smith_chart_stability_judgment_module/stability_region_detector.dart';

enum SourceLoadInputMode {
  gamma, // input Γs, ΓL
  impedance, // input Zs, ZL
}

class StepPanel {
  final String titleLatex;
  final List<Widget> content;
  StepPanel({required this.titleLatex, required this.content});
}

class AmplifierCalculator {
  final Complex s11, s12, s21, s22;
  final Complex zs, zl;
  final Complex gammaS, gammaL;
  final double z0;
  final SourceLoadInputMode inputMode;

  AmplifierCalculator({
    required this.s11,
    required this.s12,
    required this.s21,
    required this.s22,
    required this.zs,
    required this.zl,
    required this.gammaS,
    required this.gammaL,
    required this.inputMode,
    this.z0 = 50.0,
  });

  static const double _eps = 1e-12;

  bool _isBad(double x) => x.isNaN || x.isInfinite;

  String _texNumSafe(double val) {
    if (val.isNaN) return r'\text{NaN}';
    if (val.isInfinite) return val.isNegative ? r'-\infty' : r'\infty';
    return ComplexFormatter.smartFormat(val, useLatex: true, precision: 4);
  }

  String _latexComplexSafe(Complex c, ComplexInputFormat fmt) {
    final r = c.real;
    final i = c.imaginary;
    if (_isBad(r) || _isBad(i)) return r'\text{NaN}';
    return ComplexFormatter.latex(c, fmt, precision: 4);
  }

  String _latexHybridSafe(Complex c, {int precision = 4}) {
    final r = c.real;
    final i = c.imaginary;
    if (_isBad(r) || _isBad(i)) return r'\text{NaN}';
    return ComplexFormatter.latexHybrid(c, precision: precision);
  }

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

  double _safeDivD(double num, double den) {
    if (num.isNaN || den.isNaN) return double.nan;

    if (den.abs() < _eps) {
      if (num == 0.0) return double.nan;
      final sNum = num.isNegative ? -1.0 : 1.0;
      final sDen = (den == 0.0) ? 1.0 : (den.isNegative ? -1.0 : 1.0);
      final sign = sNum * sDen;
      return sign < 0 ? double.negativeInfinity : double.infinity;
    }

    final out = num / den;
    if (out.isNaN) return double.nan;
    return out;
  }

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

  String _texNum(double val) => _texNumSafe(val);

  String formatResultLine(String label, double val) {
    String dbPart;
    if (val.isNaN) {
      dbPart = r'\text{Error}';
    } else if (val.isInfinite) {
      dbPart = r'\text{∞ (singularity)}';
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

  String _v(double x) => _texNumSafe(x);

  String _latexSubstitutionK({
    required double s11Abs,
    required double s22Abs,
    required double deltaAbs,
    required double s12Abs,
    required double s21Abs,
  }) {
    return r'K=\frac{1-|S_{11}|^2-|S_{22}|^2+|\Delta|^2}{2|S_{12}S_{21}|}'
    r'=\frac{1-(' +
        _v(s11Abs) +
        r')^2-(' +
        _v(s22Abs) +
        r')^2+(' +
        _v(deltaAbs) +
        r')^2}{2\cdot(' +
        _v(s12Abs) +
        r')\cdot(' +
        _v(s21Abs) +
        r')}';
  }

  String _latexSubstitutionKt({
    required double s11Abs,
    required double s22Abs,
    required double deltaAbs,
    required double s12Abs,
    required double s21Abs,
  }) {
    return r'K_t=\frac{3-2|S_{11}|^2-2|S_{22}|^2+|\Delta|^2-\left|1-|\Delta|^2\right|}{4|S_{12}S_{21}|}'
    r'=\frac{3-2(' +
        _v(s11Abs) +
        r')^2-2(' +
        _v(s22Abs) +
        r')^2+(' +
        _v(deltaAbs) +
        r')^2-\left|1-(' +
        _v(deltaAbs) +
        r')^2\right|}{4\cdot(' +
        _v(s12Abs) +
        r')\cdot(' +
        _v(s21Abs) +
        r')}';
  }

  String _latexSubstitutionMu({
    required String symbol,
    required double sPortAbs,
    required double termAbs,
    required double s12Abs,
    required double s21Abs,
  }) {
    return symbol +
        r'=\frac{1-|S|^2}{|T|+|S_{12}S_{21}|}'
        r'=\frac{1-(' +
        _v(sPortAbs) +
        r')^2}{(' +
        _v(termAbs) +
        r')+(' +
        _v(s12Abs) +
        r')\cdot(' +
        _v(s21Abs) +
        r')}';
  }

  List<StepPanel> buildStepPanels(ComplexInputFormat displayFormat) {
    final panels = <StepPanel>[];
    final z0Str = ComplexFormatter.smartFormat(z0);
    final Complex z0Comp = Complex(z0, 0);
    final step1Content = <Widget>[];

    if (inputMode == SourceLoadInputMode.impedance) {
      final numS = zs - z0Comp;
      final denS = zs + z0Comp;
      final numL = zl - z0Comp;
      final denL = zl + z0Comp;

      step1Content.addAll([
        _text('Mode: Impedance (Z) Input. Calculating reflection coefficients (Γ).', bold: true),
        _texScroll(r'Z_0 = ' + z0Str + r'\;\Omega'),
        _text('General Formula:', bold: true),
        _texScroll(r'\Gamma = \frac{Z - Z_0}{Z + Z_0}'),
        const Divider(),
        _text('Source Reflection (Γs):', bold: true),
        _texScroll(r'Z_S = ' + _latexComplexSafe(zs, displayFormat) + r'\;\Omega'),
        _texScroll(
            r'\Gamma_S = \frac{(' + _latexComplexSafe(zs, displayFormat) + r') - ' + z0Str +
                r'}{(' + _latexComplexSafe(zs, displayFormat) + r') + ' + z0Str + r'}'
        ),
        _texScroll(
            r'= \frac{' + _latexComplexSafe(numS, displayFormat) +
                r'}{' + _latexComplexSafe(denS, displayFormat) +
                r'} = \mathbf{' + _latexComplexSafe(gammaS, displayFormat) + r'}'
        ),
        if (denS.modulus < _eps) _text('⚠ Warning: Z_S + Z_0 ≈ 0, Γs is near a singularity.', bold: true),
        const Divider(),
        _text('Load Reflection (ΓL):', bold: true),
        _texScroll(r'Z_L = ' + _latexComplexSafe(zl, displayFormat) + r'\;\Omega'),
        _texScroll(
            r'\Gamma_L = \frac{(' + _latexComplexSafe(zl, displayFormat) + r') - ' + z0Str +
                r'}{(' + _latexComplexSafe(zl, displayFormat) + r') + ' + z0Str + r'}'
        ),
        _texScroll(
            r'= \frac{' + _latexComplexSafe(numL, displayFormat) +
                r'}{' + _latexComplexSafe(denL, displayFormat) +
                r'} = \mathbf{' + _latexComplexSafe(gammaL, displayFormat) + r'}'
        ),
        if (denL.modulus < _eps) _text('⚠ Warning: Z_L + Z_0 ≈ 0, ΓL is near a singularity.', bold: true),
      ]);
    } else {

      final numS = Complex(1, 0) + gammaS;
      final denS = Complex(1, 0) - gammaS;
      final numL = Complex(1, 0) + gammaL;
      final denL = Complex(1, 0) - gammaL;

      step1Content.addAll([
        _text('Mode: Reflection Coefficient (Γ) Input. Calculating equivalent port impedances (Z).', bold: true),
        _texScroll(r'Z_0 = ' + z0Str + r'\;\Omega'),
        _text('General Formula:', bold: true),
        _texScroll(r'Z = Z_0 \frac{1 + \Gamma}{1 - \Gamma}'),
        const Divider(),
        _text('Source Impedance (Zs):', bold: true),
        _texScroll(r'\Gamma_S = ' + _latexComplexSafe(gammaS, displayFormat)),
        _texScroll(
            r'Z_S = ' + z0Str + r' \cdot \frac{1 + (' + _latexComplexSafe(gammaS, displayFormat) +
                r')}{1 - (' + _latexComplexSafe(gammaS, displayFormat) + r')}'
        ),
        _texScroll(
            r'= ' + z0Str + r' \cdot \frac{' + _latexComplexSafe(numS, displayFormat) +
                r'}{' + _latexComplexSafe(denS, displayFormat) +
                r'} = \mathbf{' + _latexComplexSafe(zs, displayFormat) + r'\;\Omega}'
        ),
        if (denS.modulus < _eps) _text('⚠ Warning: 1 - Γs ≈ 0, Zs is near a singularity (Open Circuit).', bold: true),
        const Divider(),
        _text('Load Impedance (ZL):', bold: true),
        _texScroll(r'\Gamma_L = ' + _latexComplexSafe(gammaL, displayFormat)),
        _texScroll(
            r'Z_L = ' + z0Str + r' \cdot \frac{1 + (' + _latexComplexSafe(gammaL, displayFormat) +
                r')}{1 - (' + _latexComplexSafe(gammaL, displayFormat) + r')}'
        ),
        _texScroll(
            r'= ' + z0Str + r' \cdot \frac{' + _latexComplexSafe(numL, displayFormat) +
                r'}{' + _latexComplexSafe(denL, displayFormat) +
                r'} = \mathbf{' + _latexComplexSafe(zl, displayFormat) + r'\;\Omega}'
        ),
        if (denL.modulus < _eps) _text('⚠ Warning: 1 - ΓL ≈ 0, ZL is near a singularity (Open Circuit).', bold: true),
      ]);
    }

    panels.add(
      StepPanel(
        titleLatex: r'1.\ \text{Source \& Load Matching Parameters}\ (\Gamma,\ Z)',
        content: step1Content,
      ),
    );

    final delta = s11 * s22 - s12 * s21;

    panels.add(
      StepPanel(
        titleLatex: r'2.\ \text{Determinant}\ (\Delta)',
        content: [
          _text('Formula:', bold: true),
          _texScroll(r'\Delta = S_{11} S_{22} - S_{12} S_{21}'),
          _text('Substitution:', bold: true),
          _texScroll(
            r'\Delta = (' +
                _latexComplexSafe(s11, displayFormat) +
                r')(' +
                _latexComplexSafe(s22, displayFormat) +
                r') - (' +
                _latexComplexSafe(s12, displayFormat) +
                r')(' +
                _latexComplexSafe(s21, displayFormat) +
                r')',
          ),
          const Divider(),
          _text('Result:', bold: true),
          _texScroll(r'\Delta = ' + _latexComplexSafe(delta, displayFormat)),
          _texScroll(r'|\Delta| = ' + _texNum(delta.modulus)),
        ],
      ),
    );

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
        titleLatex: r'3.\ \text{Input/Output Reflection}\ (\Gamma_{in},\ \Gamma_{out})',
        content: [
          // ===== Γin =====
          _text('Input Reflection (Γin)', bold: true),
          _text('Formula:', bold: true),
          _texScroll(r'\Gamma_{in} = S_{11} + \frac{S_{12} S_{21} \Gamma_L}{1 - S_{22} \Gamma_L}'),
          _text('Substitution:', bold: true),
          _texScroll(
            r'\Gamma_{in} = ' +
                _latexComplexSafe(s11, displayFormat) +
                r' + \frac{(' +
                _latexComplexSafe(s12, displayFormat) +
                r')(' +
                _latexComplexSafe(s21, displayFormat) +
                r')(' +
                _latexComplexSafe(gammaL, displayFormat) +
                r')}{1 - (' +
                _latexComplexSafe(s22, displayFormat) +
                r')(' +
                _latexComplexSafe(gammaL, displayFormat) +
                r')}',
          ),
          if (singularIn)
            _text('⚠ Warning: (1 - S22·ΓL) ≈ 0, Γin is near a singularity (may become NaN/∞).', bold: true),
          _text('Result:', bold: true),
          _texScroll(r'\Gamma_{in} = ' + _latexComplexSafe(gammaIn, displayFormat)),

          const Divider(),

          _text('Output Reflection (Γout)', bold: true),
          _text('Formula:', bold: true),
          _texScroll(r'\Gamma_{out} = S_{22} + \frac{S_{12} S_{21} \Gamma_S}{1 - S_{11} \Gamma_S}'),
          _text('Substitution:', bold: true),
          _texScroll(
            r'\Gamma_{out} = ' +
                _latexComplexSafe(s22, displayFormat) +
                r' + \frac{(' +
                _latexComplexSafe(s12, displayFormat) +
                r')(' +
                _latexComplexSafe(s21, displayFormat) +
                r')(' +
                _latexComplexSafe(gammaS, displayFormat) +
                r')}{1 - (' +
                _latexComplexSafe(s11, displayFormat) +
                r')(' +
                _latexComplexSafe(gammaS, displayFormat) +
                r')}',
          ),
          if (singularOut)
            _text('⚠ Warning: (1 - S11·ΓS) ≈ 0, Γout is near a singularity (may become NaN/∞).', bold: true),
          _text('Result:', bold: true),
          _texScroll(r'\Gamma_{out} = ' + _latexComplexSafe(gammaOut, displayFormat)),
        ],
      ),
    );

    final double gsMagSq = pow(gammaS.modulus, 2).toDouble();
    final double glMagSq = pow(gammaL.modulus, 2).toDouble();
    final double s21MagSq = pow(s21.modulus, 2).toDouble();
    final double ginMagSq = pow(gammaIn.modulus, 2).toDouble();
    final double goutMagSq = pow(gammaOut.modulus, 2).toDouble();
    final double denom_In_S = pow((Complex(1, 0) - gammaIn * gammaS).modulus, 2).toDouble();
    final double denom_22_L = pow((Complex(1, 0) - s22 * gammaL).modulus, 2).toDouble();
    final double denom_11_S = pow((Complex(1, 0) - s11 * gammaS).modulus, 2).toDouble();
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
        titleLatex: r'4.\ \text{Power Gains}\ (G_t,\ G_p,\ G_a)',
        content: [
          _text('To calculate gains, we break down the formula into three parts: Input Mismatch, Device Gain, and Output Mismatch.'),
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
                _texScroll(r'|\Gamma_S|^2 = ' + _texNum(gsMagSq) + r', \quad |\Gamma_L|^2 = ' + _texNum(glMagSq)),
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
            r'G_t = \underbrace{\frac{1 - |\Gamma_S|^2}{|1 - \Gamma_{in}\Gamma_S|^2}}_{\text{Input}} \cdot '
            r'\underbrace{|S_{21}|^2}_{\text{Device}} \cdot '
            r'\underbrace{\frac{1 - |\Gamma_L|^2}{|1 - S_{22}\Gamma_L|^2}}_{\text{Output}}',
          ),
          _text('Substitution:', bold: true),
          _texScroll(
            r'G_t \approx \left( \frac{1 - ' +
                _texNum(gsMagSq) +
                r'}{' +
                _texNum(denom_In_S) +
                r'} \right) \cdot ' +
                _texNum(s21MagSq) +
                r' \cdot \left( \frac{1 - ' +
                _texNum(glMagSq) +
                r'}{' +
                _texNum(denom_22_L) +
                r'} \right)',
          ),
          _texScroll(r'\Rightarrow G_t \approx (' + _texNum(gt_term1) + r') \cdot (' + _texNum(s21MagSq) + r') \cdot (' + _texNum(gt_term3) + r')'),
          _text('Result:', bold: true),
          _texScroll(formatResultLine('G_t', gt)),
          const Divider(),
          _text('2. Operating Power Gain (Gp)', bold: true),
          _texScroll(
            r'G_p = \frac{1}{1 - |\Gamma_{in}|^2} \cdot |S_{21}|^2 \cdot \frac{1 - |\Gamma_L|^2}{|1 - S_{22}\Gamma_L|^2}',
          ),
          _text('Substitution:', bold: true),
          _texScroll(
            r'G_p \approx \left( \frac{1}{1 - ' +
                _texNum(ginMagSq) +
                r'} \right) \cdot ' +
                _texNum(s21MagSq) +
                r' \cdot (' +
                _texNum(gt_term3) +
                r')',
          ),
          _text('Result:', bold: true),
          _texScroll(formatResultLine('G_p', gp)),
          const Divider(),
          _text('3. Available Power Gain (Ga)', bold: true),
          _texScroll(
            r'G_a = \frac{1 - |\Gamma_S|^2}{|1 - S_{11}\Gamma_S|^2} \cdot |S_{21}|^2 \cdot \frac{1}{1 - |\Gamma_{out}|^2}',
          ),
          _text('Substitution:', bold: true),
          _texScroll(
            r'G_a \approx (' +
                _texNum(ga_term1) +
                r') \cdot ' +
                _texNum(s21MagSq) +
                r' \cdot \left( \frac{1}{1 - ' +
                _texNum(goutMagSq) +
                r'} \right)',
          ),
          _text('Result:', bold: true),
          _texScroll(formatResultLine('G_a', ga)),
        ],
      ),
    );

    const double epsilon = 1e-9;
    final bool isUnilateral = (s12.modulus < epsilon) || (s21.modulus < epsilon);

    final double s11Abs = s11.modulus;
    final double s22Abs = s22.modulus;
    final double s12Abs = s12.modulus;
    final double s21Abs = s21.modulus;
    final double s11MagSq2 = s11Abs * s11Abs;
    final double s22MagSq2 = s22Abs * s22Abs;
    final double deltaAbsVal = delta.modulus;
    final double deltaMagSq2 = deltaAbsVal * deltaAbsVal;
    final double denomK = 2.0 * s12Abs * s21Abs;
    final double numeratorK = 1.0 - s11MagSq2 - s22MagSq2 + deltaMagSq2;
    final double k = _safeDivD(numeratorK, denomK);
    final double denomKt = 4.0 * s12Abs * s21Abs;
    final double numeratorKt = 3.0 - 2.0 * s11MagSq2 - 2.0 * s22MagSq2 + deltaMagSq2 - (1.0 - deltaMagSq2).abs();
    final double kt = _safeDivD(numeratorKt, denomKt);
    final double muNumerator = 1.0 - s11MagSq2;
    final Complex term1MuComplex = s22 - delta * s11.conjugate();
    final double term1Mu = term1MuComplex.modulus;
    final double term2_stability = s12Abs * s21Abs;
    final double mu = _safeDivD(muNumerator, (term1Mu + term2_stability));
    final double muPrimeNumerator = 1.0 - s22MagSq2;
    final Complex term1MuPrimeComplex = s11 - delta * s22.conjugate();
    final double term1MuPrime = term1MuPrimeComplex.modulus;
    final double muPrime = _safeDivD(muPrimeNumerator, (term1MuPrime + term2_stability));
    final bool stableByK = (k > 1.0) && (deltaAbsVal < 1.0);
    final bool stableByKt = (kt > 1.0);
    final bool stableByMu = (mu > 1.0) && (muPrime > 1.0);

    if (isUnilateral) {
      final bool isStableUni = (s11Abs < 1.0) && (s22Abs < 1.0);

      panels.add(
        StepPanel(
          titleLatex: r'5.\ \text{Stability Analysis (Unilateral)}\ (+K,\ K_t,\ \mu,\ \mu^\prime)',
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
                      r'Unilateral Condition Detected (|S12| ≈ 0 or |S21| ≈ 0). '
                      r'We will STILL compute K, Kt, μ, μ′. When |S12·S21| → 0, K and Kt may become +∞ or −∞.',
                      bold: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _text('Primary (Unilateral) Stability Check:', bold: true),
            _texScroll(r'|S_{11}| < 1 \quad \text{and} \quad |S_{22}| < 1'),
            _text('Substitution:', bold: true),
            _texScroll(r'|S_{11}| = ' + _texNum(s11Abs)),
            _texScroll(r'|S_{22}| = ' + _texNum(s22Abs)),
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
                          isStableUni ? "Unconditionally Stable (Unilateral Test)" : "Potentially Unstable (Unilateral Test)",
                          style: TextStyle(
                            color: isStableUni ? Colors.green[800] : Colors.deepOrange[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isStableUni ? "|S11| < 1 and |S22| < 1 satisfied." : "Input or Output port has negative resistance (|Sxx| > 1).",
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
            const Divider(),
            _text('Reference Computations (still computed):', bold: true),
            _text('0) Determinant (Δ)', bold: true),
            _texScroll(r'\Delta = S_{11} S_{22} - S_{12} S_{21}'),
            _texScroll(r'\Delta = ' + _latexComplexSafe(delta, displayFormat)),
            _texScroll(r'|\Delta| = ' + _texNum(deltaAbsVal)),
            const Divider(),
            _text('1) Rollett Factor (K)', bold: true),
            _texScroll(r'K=\frac{1-|S_{11}|^2-|S_{22}|^2+|\Delta|^2}{2|S_{12}S_{21}|}'),
            _text('Substitution (only replace values, do not simplify):', bold: true),
            _texScroll(
              _latexSubstitutionK(
                s11Abs: s11Abs,
                s22Abs: s22Abs,
                deltaAbs: deltaAbsVal,
                s12Abs: s12Abs,
                s21Abs: s21Abs,
              ),
            ),
            _text('Computed Result:', bold: true),
            _texScroll(r'K=\mathbf{' + _texNum(k) + r'}'),
            if (k.isInfinite)
              _text(
                k.isNegative ? '⚠ K = −∞ (denominator → 0 and numerator < 0)' : '⚠ K = +∞ (denominator → 0 and numerator > 0)',
                bold: true,
              ),
            _text(stableByK ? '✓ (A) satisfied (numerically): K > 1 and |Δ| < 1' : '✗ (A) not satisfied (numerically)', bold: true),
            const Divider(),
            _text('2) Single-Parameter Stability Criterion (Kt)', bold: true),
            _texScroll(
              r'K_t=\frac{3-2|S_{11}|^2-2|S_{22}|^2+|\Delta|^2-\left|1-|\Delta|^2\right|}{4|S_{12}S_{21}|}',
            ),
            _text('Substitution (only replace values, do not simplify):', bold: true),
            _texScroll(
              _latexSubstitutionKt(
                s11Abs: s11Abs,
                s22Abs: s22Abs,
                deltaAbs: deltaAbsVal,
                s12Abs: s12Abs,
                s21Abs: s21Abs,
              ),
            ),
            _text('Computed Result:', bold: true),
            _texScroll(r'K_t=\mathbf{' + _texNum(kt) + r'}'),
            if (kt.isInfinite)
              _text(
                kt.isNegative ? '⚠ Kt = −∞ (denominator → 0 and numerator < 0)' : '⚠ Kt = +∞ (denominator → 0 and numerator > 0)',
                bold: true,
              ),
            _text(stableByKt ? '✓ (B) satisfied (numerically): Kt > 1' : '✗ (B) not satisfied (numerically)', bold: true),
            const Divider(),
            _text('3) Geometric Stability Factor (μ)', bold: true),
            _texScroll(r'\mu=\frac{1-|S_{11}|^2}{|S_{22}-\Delta S_{11}^*|+|S_{12}S_{21}|}'),
            _text('Intermediate term (under current format):', bold: true),
            _texScroll(
              r'S_{22}-\Delta S_{11}^* = (' +
                  _latexComplexSafe(s22, displayFormat) +
                  r')-(' +
                  _latexComplexSafe(delta, displayFormat) +
                  r')(' +
                  _latexComplexSafe(s11.conjugate(), displayFormat) +
                  r')',
            ),
            _texScroll(
              r'S_{22}-\Delta S_{11}^*=' +
                  _latexComplexSafe(term1MuComplex, displayFormat) +
                  r',\quad |S_{22}-\Delta S_{11}^*|=' +
                  _texNum(term1Mu),
            ),
            _text('Substitution (only replace values, do not simplify):', bold: true),
            _texScroll(
              _latexSubstitutionMu(
                symbol: r'\mu',
                sPortAbs: s11Abs,
                termAbs: term1Mu,
                s12Abs: s12Abs,
                s21Abs: s21Abs,
              ) +
                  r'\;=\;' +
                  _texNum(mu),
            ),
            _text('Computed Result:', bold: true),
            _texScroll(r'\mu=\mathbf{' + _texNum(mu) + r'}'),
            const Divider(),
            _text("4) Geometric Stability Factor (μ')", bold: true),
            _texScroll(r"\mu^\prime=\frac{1-|S_{22}|^2}{|S_{11}-\Delta S_{22}^*|+|S_{12}S_{21}|}"),
            _text('Intermediate term (under current format):', bold: true),
            _texScroll(
              r'S_{11}-\Delta S_{22}^* = (' +
                  _latexComplexSafe(s11, displayFormat) +
                  r')-(' +
                  _latexComplexSafe(delta, displayFormat) +
                  r')(' +
                  _latexComplexSafe(s22.conjugate(), displayFormat) +
                  r')',
            ),
            _texScroll(
              r'S_{11}-\Delta S_{22}^*=' +
                  _latexComplexSafe(term1MuPrimeComplex, displayFormat) +
                  r",\quad |S_{11}-\Delta S_{22}^*|=" +
                  _texNum(term1MuPrime),
            ),
            _text('Substitution (only replace values, do not simplify):', bold: true),
            _texScroll(
              _latexSubstitutionMu(
                symbol: r"\mu^\prime",
                sPortAbs: s22Abs,
                termAbs: term1MuPrime,
                s12Abs: s12Abs,
                s21Abs: s21Abs,
              ) +
                  r'\;=\;' +
                  _texNum(muPrime),
            ),
            _text('Computed Result:', bold: true),
            _texScroll(r"\mu^\prime=\mathbf{" + _texNum(muPrime) + r"}"),
            const SizedBox(height: 8),
            _text(
              'Note: In unilateral cases, K/Kt can blow up to ±∞ because the denominator contains |S12·S21|. '
                  'So the final stability decision here uses the unilateral passivity test.',
              bold: true,
            ),
          ],
        ),
      );
    } else {
      final bool isUnconditionallyStable = stableByK || stableByKt || stableByMu;

      panels.add(
        StepPanel(
          titleLatex: r'5.\ \text{Stability Analysis}\ (K,\ \Delta,\ K_t,\ \mu,\ \mu^\prime)',
          content: [
            _text('Stability criteria ensure the amplifier does not oscillate.'),
            _text('Unconditional Stability Conditions (Sufficient tests):', bold: true),
            _texScroll(r'\text{(A)}\;\;K>1 \ \text{and}\ |\Delta|<1'),
            _texScroll(r'\text{(B)}\;\;K_t>1'),
            _texScroll(r"\text{(C)}\;\;\mu>1 \ \text{and}\ \mu^\prime>1"),
            const SizedBox(height: 8),
            _text('0) Determinant (Δ)', bold: true),
            _texScroll(r'\Delta = S_{11}S_{22}-S_{12}S_{21}'),
            _text('Substitution (only replace values):', bold: true),
            _texScroll(
              r'\Delta=(' +
                  _latexComplexSafe(s11, displayFormat) +
                  r')(' +
                  _latexComplexSafe(s22, displayFormat) +
                  r')-(' +
                  _latexComplexSafe(s12, displayFormat) +
                  r')(' +
                  _latexComplexSafe(s21, displayFormat) +
                  r')',
            ),
            _text('Result:', bold: true),
            _texScroll(r'\Delta=' + _latexComplexSafe(delta, displayFormat)),
            _texScroll(r'|\Delta|=' + _texNum(deltaAbsVal)),
            const Divider(),
            _text('1) Rollett Factor (K)', bold: true),
            _texScroll(r'K=\frac{1-|S_{11}|^2-|S_{22}|^2+|\Delta|^2}{2|S_{12}S_{21}|}'),
            _text('Substitution (only replace values, do not simplify):', bold: true),
            _texScroll(
              _latexSubstitutionK(
                s11Abs: s11Abs,
                s22Abs: s22Abs,
                deltaAbs: deltaAbsVal,
                s12Abs: s12Abs,
                s21Abs: s21Abs,
              ),
            ),
            _text('Computed Result:', bold: true),
            _texScroll(r'K=\mathbf{' + _texNum(k) + r'}'),
            _texScroll(r'|\Delta|=\mathbf{' + _texNum(deltaAbsVal) + r'}'),
            _text(stableByK ? '✓ Condition (A) satisfied: K > 1 and |Δ| < 1' : '✗ Condition (A) not satisfied', bold: true),
            const Divider(),
            _text('2) Single-Parameter Stability Criterion (Kt)', bold: true),
            _texScroll(
              r'K_t=\frac{3-2|S_{11}|^2-2|S_{22}|^2+|\Delta|^2-\left|1-|\Delta|^2\right|}{4|S_{12}S_{21}|}',
            ),
            _text('Substitution (only replace values, do not simplify):', bold: true),
            _texScroll(
              _latexSubstitutionKt(
                s11Abs: s11Abs,
                s22Abs: s22Abs,
                deltaAbs: deltaAbsVal,
                s12Abs: s12Abs,
                s21Abs: s21Abs,
              ),
            ),
            _text('Computed Result:', bold: true),
            _texScroll(r'K_t=\mathbf{' + _texNum(kt) + r'}'),
            _text(stableByKt ? '✓ Condition (B) satisfied: Kt > 1' : '✗ Condition (B) not satisfied', bold: true),
            const Divider(),
            _text('3) Geometric Stability Factor (μ)', bold: true),
            _texScroll(r'\mu=\frac{1-|S_{11}|^2}{|S_{22}-\Delta S_{11}^*|+|S_{12}S_{21}|}'),
            _text('Intermediate term (under current format):', bold: true),
            _texScroll(
              r'S_{22}-\Delta S_{11}^* = (' +
                  _latexComplexSafe(s22, displayFormat) +
                  r')-(' +
                  _latexComplexSafe(delta, displayFormat) +
                  r')(' +
                  _latexComplexSafe(s11.conjugate(), displayFormat) +
                  r')',
            ),
            _texScroll(
              r'S_{22}-\Delta S_{11}^*=' +
                  _latexComplexSafe(term1MuComplex, displayFormat) +
                  r',\quad |S_{22}-\Delta S_{11}^*|=' +
                  _texNum(term1Mu),
            ),
            _text('Substitution (only replace values, do not simplify):', bold: true),
            _texScroll(
              _latexSubstitutionMu(
                symbol: r'\mu',
                sPortAbs: s11Abs,
                termAbs: term1Mu,
                s12Abs: s12Abs,
                s21Abs: s21Abs,
              ),
            ),
            _text('Computed Result:', bold: true),
            _texScroll(r'\mu=\mathbf{' + _texNum(mu) + r'}'),
            const Divider(),
            _text("4) Geometric Stability Factor (μ')", bold: true),
            _texScroll(r"\mu^\prime=\frac{1-|S_{22}|^2}{|S_{11}-\Delta S_{22}^*|+|S_{12}S_{21}|}"),
            _text('Intermediate term (under current format):', bold: true),
            _texScroll(
              r'S_{11}-\Delta S_{22}^* = (' +
                  _latexComplexSafe(s11, displayFormat) +
                  r')-(' +
                  _latexComplexSafe(delta, displayFormat) +
                  r')(' +
                  _latexComplexSafe(s22.conjugate(), displayFormat) +
                  r')',
            ),
            _texScroll(
              r'S_{11}-\Delta S_{22}^*=' +
                  _latexComplexSafe(term1MuPrimeComplex, displayFormat) +
                  r",\quad |S_{11}-\Delta S_{22}^*|=" +
                  _texNum(term1MuPrime),
            ),
            _text('Substitution (only replace values, do not simplify):', bold: true),
            _texScroll(
              _latexSubstitutionMu(
                symbol: r"\mu^\prime",
                sPortAbs: s22Abs,
                termAbs: term1MuPrime,
                s12Abs: s12Abs,
                s21Abs: s21Abs,
              ),
            ),
            _text('Computed Result:', bold: true),
            _texScroll(r"\mu^\prime=\mathbf{" + _texNum(muPrime) + r"}"),
            _text(stableByMu ? "✓ Condition (C) satisfied: μ > 1 and μ′ > 1" : "✗ Condition (C) not satisfied", bold: true),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnconditionallyStable ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isUnconditionallyStable ? Colors.green : Colors.deepOrange,
                  width: 2,
                ),
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
                          isUnconditionallyStable ? "At least one sufficient condition (A/B/C) is satisfied." : "None of (A/B/C) is satisfied. Use stability circles/regions.",
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

class ExamplePreset {
  final String name;
  final String freqGHz;
  final String z0;
  final String s11Mag, s11Ang;
  final String s12Mag, s12Ang;
  final String s21Mag, s21Ang;
  final String s22Mag, s22Ang;
  final String gammaSMag, gammaSAng;
  final String gammaLMag, gammaLAng;

  const ExamplePreset({
    required this.name,
    required this.freqGHz,
    required this.z0,
    required this.s11Mag,
    required this.s11Ang,
    required this.s12Mag,
    required this.s12Ang,
    required this.s21Mag,
    required this.s21Ang,
    required this.s22Mag,
    required this.s22Ang,
    this.gammaSMag = '0',
    this.gammaSAng = '0',
    this.gammaLMag = '0',
    this.gammaLAng = '0',
  });
}

class AmplifierHomePage extends StatefulWidget {
  const AmplifierHomePage({super.key});

  @override
  State<AmplifierHomePage> createState() => _AmplifierHomePageState();
}

class _AmplifierHomePageState extends State<AmplifierHomePage> {
  final _formKey = GlobalKey<FormState>();
  final freqController = TextEditingController(text: '9');
  final s11C1 = TextEditingController(text: '0.89');
  final s11C2 = TextEditingController(text: '-60.73');
  final s12C1 = TextEditingController(text: '0.02');
  final s12C2 = TextEditingController(text: '62.45');
  final s21C1 = TextEditingController(text: '3.12');
  final s21C2 = TextEditingController(text: '123.76');
  final s22C1 = TextEditingController(text: '0.78');
  final s22C2 = TextEditingController(text: '-27.50');
  final z0C = TextEditingController(text: '50');

  SourceLoadInputMode _slMode = SourceLoadInputMode.gamma;
  bool _isSyncingSL = false;

  final gammaSC1 = TextEditingController(text: '0');
  final gammaSC2 = TextEditingController(text: '0');
  final gammaLC1 = TextEditingController(text: '0');
  final gammaLC2 = TextEditingController(text: '0');
  final zsC1 = TextEditingController(text: '50');
  final zsC2 = TextEditingController(text: '0');
  final zlC1 = TextEditingController(text: '50');
  final zlC2 = TextEditingController(text: '0');

  ComplexInputFormat _currentFormat = ComplexInputFormat.polarDegree;

  List<bool> _expandedList = [];
  List<StepPanel> _stepPanels = [];
  bool _sourceRegionExpanded = false;
  bool _loadRegionExpanded = false;
  Widget? _sourceRegionWidget;
  Widget? _loadRegionWidget;
  Complex? sourceCenter, loadCenter;
  double? sourceRadius, loadRadius;
  double? s22Abs, s11Abs;
  bool isPotentiallyUnstableSource = false;
  bool isPotentiallyUnstableLoad = false;

  static const double _eps = 1e-12;

  Timer? _debounce;

  void _scheduleAutoCalc() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (_formKey.currentState?.validate() ?? false) {
        calculate();
      }
    });
  }

  void _submitCalcNow() {
    _debounce?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    calculate();
  }

  Widget _tapBlankToCalc({required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        calculate();
      },
      child: child,
    );
  }

  String? _optionalNumberValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    return commonValidator(v);
  }

  double _parseOrDefault(TextEditingController c, double def) {
    final s = c.text.trim();
    if (s.isEmpty) return def;
    return double.tryParse(s) ?? def;
  }

  double _safeDivD(double num, double den) {
    if (num.isNaN || den.isNaN) return double.nan;

    if (den.abs() < _eps) {
      if (num == 0.0) return double.nan;
      final sNum = num.isNegative ? -1.0 : 1.0;
      final sDen = (den == 0.0) ? 1.0 : (den.isNegative ? -1.0 : 1.0);
      final sign = sNum * sDen;
      return sign < 0 ? double.negativeInfinity : double.infinity;
    }

    final out = num / den;
    if (out.isNaN) return double.nan;
    return out;
  }

  double _z0ForConversion() {
    final s = z0C.text.trim();
    if (s.isEmpty) return 50.0;
    final v = double.tryParse(s);
    return v ?? 50.0;
  }

  Complex? _tryParseComplexControllers(TextEditingController c1, TextEditingController c2) {
    try {
      return ComplexParser.parseUniversal(_joinInput(c1, c2), _currentFormat);
    } catch (_) {
      return null;
    }
  }

  void _setComplexControllers(TextEditingController c1, TextEditingController c2, Complex value) {
    if (_currentFormat == ComplexInputFormat.cartesian) {
      c1.text = ComplexFormatter.smartFormat(value.real, useScientific: false, precision: 6);
      c2.text = ComplexFormatter.smartFormat(value.imaginary, useScientific: false, precision: 6);
      return;
    }

    final mag = value.modulus;
    final phaseRad = value.phase();
    final angle = (_currentFormat == ComplexInputFormat.polarDegree) ? (phaseRad * 180 / pi) : phaseRad;

    c1.text = ComplexFormatter.smartFormat(mag, useScientific: false, precision: 6);
    c2.text = ComplexFormatter.smartFormat(angle, useScientific: false, precision: 6);
  }

  void _syncSourceLoadByMode({bool force = false}) {
    if (_isSyncingSL) return;
    _isSyncingSL = true;

    Complex? gammaFromZ(Complex z, double z0) {
      final denom = z + Complex(z0, 0);
      if (denom.modulus < 1e-9) return null;
      return (z - Complex(z0, 0)) / denom;
    }

    Complex? zFromGamma(Complex g, double z0) {
      final denom = Complex(1, 0) - g;
      if (denom.modulus < 1e-9) return null;
      return Complex(z0, 0) * (Complex(1, 0) + g) / denom;
    }

    final z0 = _z0ForConversion();

    if (_slMode == SourceLoadInputMode.gamma) {
      final gs = _tryParseComplexControllers(gammaSC1, gammaSC2);
      final gl = _tryParseComplexControllers(gammaLC1, gammaLC2);

      if (gs != null) {
        final zs = zFromGamma(gs, z0);
        if (zs != null) _setComplexControllers(zsC1, zsC2, zs);
      }
      if (gl != null) {
        final zl = zFromGamma(gl, z0);
        if (zl != null) _setComplexControllers(zlC1, zlC2, zl);
      }
    } else {
      final zs = _tryParseComplexControllers(zsC1, zsC2);
      final zl = _tryParseComplexControllers(zlC1, zlC2);

      if (zs != null) {
        final gs = gammaFromZ(zs, z0);
        if (gs != null) _setComplexControllers(gammaSC1, gammaSC2, gs);
      }
      if (zl != null) {
        final gl = gammaFromZ(zl, z0);
        if (gl != null) _setComplexControllers(gammaLC1, gammaLC2, gl);
      }
    }

    _isSyncingSL = false;
  }

  void _setSourceLoadMode(SourceLoadInputMode m) {
    if (m == _slMode) return;
    setState(() {
      _slMode = m;
    });
    _syncSourceLoadByMode();
  }

  late final List<ExamplePreset> _examples = [
    const ExamplePreset(
      name: 'Example 4-1 (MESFET, 9 GHz)',
      freqGHz: '9',
      z0: '50',
      s11Mag: '0.894', s11Ang: '-60.6',
      s12Mag: '0.02',  s12Ang: '62.4',
      s21Mag: '3.122', s21Ang: '123.6',
      s22Mag: '0.781', s22Ang: '-27.6',
      gammaSMag: '0', gammaSAng: '0',
      gammaLMag: '0', gammaLAng: '0',
    ),
    const ExamplePreset(
      name: 'Example 4-2 (Transistor, 9 GHz)',
      freqGHz: '9',
      z0: '',
      s11Mag: '0.65',  s11Ang: '-95',
      s12Mag: '0.035', s12Ang: '40',
      s21Mag: '5',     s21Ang: '115',
      s22Mag: '0.8',   s22Ang: '-35',
      gammaSMag: '0', gammaSAng: '0',
      gammaLMag: '0', gammaLAng: '0',
    ),
    const ExamplePreset(
      name: 'Unilateral Test (S12 ≈ 0)',
      freqGHz: '',
      z0: '50',
      s11Mag: '0.75', s11Ang: '-30',
      s12Mag: '0.0',  s12Ang: '0',
      s21Mag: '2.5',  s21Ang: '90',
      s22Mag: '0.6',  s22Ang: '-20',
      gammaSMag: '0', gammaSAng: '0',
      gammaLMag: '0', gammaLAng: '0',
    ),
    const ExamplePreset(
      name: 'Singularity Test (1 - S22·ΓL ≈ 0)',
      freqGHz: '',
      z0: '50',
      s11Mag: '0.5',  s11Ang: '-10',
      s12Mag: '0.05', s12Ang: '30',
      s21Mag: '2',    s21Ang: '60',
      s22Mag: '1.0',  s22Ang: '0',
      gammaSMag: '0', gammaSAng: '0',
      gammaLMag: '0.999', gammaLAng: '0',
    ),
    const ExamplePreset(
      name: 'Z Singularity Test (Zs + Z0 ≈ 0)',
      freqGHz: '',
      z0: '50',
      s11Mag: '0.8',  s11Ang: '-45',
      s12Mag: '0.08', s12Ang: '20',
      s21Mag: '3.2',  s21Ang: '110',
      s22Mag: '0.7',  s22Ang: '-10',
      gammaSMag: '0.999', gammaSAng: '180',
      gammaLMag: '0', gammaLAng: '0',
    ),
    const ExamplePreset(
      name: 'Potentially Unstable (strong feedback)',
      freqGHz: '',
      z0: '50',
      s11Mag: '0.92', s11Ang: '-150',
      s12Mag: '0.18', s12Ang: '20',
      s21Mag: '1.6',  s21Ang: '80',
      s22Mag: '0.9',  s22Ang: '-120',
      gammaSMag: '0', gammaSAng: '0',
      gammaLMag: '0', gammaLAng: '0',
    ),
  ];

  int _exampleIndex = 0;

  void _applyExample(ExamplePreset ex) {
    _currentFormat = ComplexInputFormat.polarDegree;
    _slMode = SourceLoadInputMode.gamma;

    freqController.text = ex.freqGHz;
    z0C.text = ex.z0;

    s11C1.text = ex.s11Mag; s11C2.text = ex.s11Ang;
    s12C1.text = ex.s12Mag; s12C2.text = ex.s12Ang;
    s21C1.text = ex.s21Mag; s21C2.text = ex.s21Ang;
    s22C1.text = ex.s22Mag; s22C2.text = ex.s22Ang;

    gammaSC1.text = ex.gammaSMag; gammaSC2.text = ex.gammaSAng;
    gammaLC1.text = ex.gammaLMag; gammaLC2.text = ex.gammaLAng;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSourceLoadByMode();
    });
  }

  void _nextExampleAndRecalculate() {
    setState(() {
      _exampleIndex = (_exampleIndex + 1) % _examples.length;

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

    calculate();
  }

  void _previousExampleAndRecalculate() {
    setState(() {
      _exampleIndex = (_exampleIndex - 1 + _examples.length) % _examples.length;

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
          double angle = (newFormat == ComplexInputFormat.polarDegree) ? c.phase() * 180 / pi : c.phase();
          c2.text = ComplexFormatter.smartFormat(angle, useScientific: false, precision: 6);
        }
      }

      updateControllers(s11, s11C1, s11C2);
      updateControllers(s12, s12C1, s12C2);
      updateControllers(s21, s21C1, s21C2);
      updateControllers(s22, s22C1, s22C2);

      final gammaS = _tryParseComplexControllers(gammaSC1, gammaSC2) ?? Complex.zero();
      final gammaL = _tryParseComplexControllers(gammaLC1, gammaLC2) ?? Complex.zero();
      final z0 = _parseOrDefault(z0C, 50.0);
      final zs = _tryParseComplexControllers(zsC1, zsC2) ?? Complex(z0, 0);
      final zl = _tryParseComplexControllers(zlC1, zlC2) ?? Complex(z0, 0);

      updateControllers(gammaS, gammaSC1, gammaSC2);
      updateControllers(gammaL, gammaLC1, gammaLC2);
      updateControllers(zs, zsC1, zsC2);
      updateControllers(zl, zlC1, zlC2);

      _currentFormat = newFormat;

      if (_stepPanels.isNotEmpty) {
        calculate();
      }
    });
  }

  void calculate() {
    if (!_formKey.currentState!.validate()) return;

    _syncSourceLoadByMode();

    final s11 = ComplexParser.parseUniversal(_joinInput(s11C1, s11C2), _currentFormat);
    final s12 = ComplexParser.parseUniversal(_joinInput(s12C1, s12C2), _currentFormat);
    final s21 = ComplexParser.parseUniversal(_joinInput(s21C1, s21C2), _currentFormat);
    final s22 = ComplexParser.parseUniversal(_joinInput(s22C1, s22C2), _currentFormat);

    final z0 = _parseOrDefault(z0C, 50.0);

    Complex gammaS, gammaL, zs, zl;
    if (_slMode == SourceLoadInputMode.gamma) {
      gammaS = _tryParseComplexControllers(gammaSC1, gammaSC2) ?? Complex.zero();
      gammaL = _tryParseComplexControllers(gammaLC1, gammaLC2) ?? Complex.zero();
      zs = _tryParseComplexControllers(zsC1, zsC2) ?? Complex(z0, 0);
      zl = _tryParseComplexControllers(zlC1, zlC2) ?? Complex(z0, 0);
    } else {
      zs = _tryParseComplexControllers(zsC1, zsC2) ?? Complex(z0, 0);
      zl = _tryParseComplexControllers(zlC1, zlC2) ?? Complex(z0, 0);
      gammaS = _tryParseComplexControllers(gammaSC1, gammaSC2) ?? Complex.zero();
      gammaL = _tryParseComplexControllers(gammaLC1, gammaLC2) ?? Complex.zero();
    }

    const double unilateralEps = 1e-9;
    final bool isUnilateral = (s12.modulus < unilateralEps || s21.modulus < unilateralEps);

    final amplifier = AmplifierCalculator(
      s11: s11,
      s12: s12,
      s21: s21,
      s22: s22,
      zs: zs,
      zl: zl,
      gammaS: gammaS,
      gammaL: gammaL,
      z0: z0,
      inputMode: _slMode,
    );

    final stepPanels = amplifier.buildStepPanels(_currentFormat);
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

    final double s11AbsVal = s11.modulus;
    final double s22AbsVal = s22.modulus;
    final double s12AbsVal = s12.modulus;
    final double s21AbsVal = s21.modulus;
    final double s11MagSq = s11AbsVal * s11AbsVal;
    final double s22MagSq = s22AbsVal * s22AbsVal;
    final double deltaAbsVal = delta.modulus;
    final double deltaMagSq = deltaAbsVal * deltaAbsVal;

    final double k = _safeDivD(1.0 - s11MagSq - s22MagSq + deltaMagSq, 2.0 * s12AbsVal * s21AbsVal);
    final double kt = _safeDivD(
      3.0 - 2.0 * s11MagSq - 2.0 * s22MagSq + deltaMagSq - (1.0 - deltaMagSq).abs(),
      4.0 * s12AbsVal * s21AbsVal,
    );

    final double mu = _safeDivD(
      1.0 - s11MagSq,
      (s22 - delta * s11.conjugate()).modulus + (s12AbsVal * s21AbsVal),
    );
    final double muPrime = _safeDivD(
      1.0 - s22MagSq,
      (s11 - delta * s22.conjugate()).modulus + (s12AbsVal * s21AbsVal),
    );

    final bool stableByK = (k > 1.0) && (deltaAbsVal < 1.0);
    final bool stableByKt = (kt > 1.0);
    final bool stableByMu = (mu > 1.0) && (muPrime > 1.0);
    final bool isUnconditionallyStable = stableByK || stableByKt || stableByMu;

    isPotentiallyUnstableSource = !isUnconditionallyStable;
    isPotentiallyUnstableLoad = !isUnconditionallyStable;

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

  Widget _modeBtn(String text, SourceLoadInputMode mode) {
    final selected = _slMode == mode;
    return ElevatedButton(
      onPressed: () => _setSourceLoadMode(mode),
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.deepPurple : Colors.grey[200],
        foregroundColor: selected ? Colors.white : Colors.black87,
        elevation: selected ? 1 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildSourceLoadSection() {
    final gammaEnabled = _slMode == SourceLoadInputMode.gamma;
    final zEnabled = _slMode == SourceLoadInputMode.impedance;

    Widget lockWrap({required bool enabled, required Widget child}) {
      return Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: AbsorbPointer(absorbing: !enabled, child: child),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F0FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Source/Load Inputs (Zs/ZL ↔ Γs/ΓL)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Switch mode locks the other inputs. Values auto-convert using current Z0 (empty = 50Ω).',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _modeBtn('Γ mode (Γs/ΓL)', SourceLoadInputMode.gamma),
              _modeBtn('Z mode (Zs/ZL)', SourceLoadInputMode.impedance),
            ],
          ),

          const SizedBox(height: 14),

          const Text(
            'Γ inputs',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          lockWrap(
            enabled: gammaEnabled,
            child: Column(
              children: [
                ComplexInputRow(
                  format: _currentFormat,
                  ctrl1: gammaSC1,
                  ctrl2: gammaSC2,
                  paramName: 'Γs',
                  validator: _optionalNumberValidator,
                  onAnyChanged: () {
                    _syncSourceLoadByMode();
                    _scheduleAutoCalc();
                  },
                  onSubmit: () {
                    _syncSourceLoadByMode();
                    _submitCalcNow();
                  },
                  action1: TextInputAction.next,
                  action2: TextInputAction.next,
                ),
                ComplexInputRow(
                  format: _currentFormat,
                  ctrl1: gammaLC1,
                  ctrl2: gammaLC2,
                  paramName: 'ΓL',
                  validator: _optionalNumberValidator,
                  onAnyChanged: () {
                    _syncSourceLoadByMode();
                    _scheduleAutoCalc();
                  },
                  onSubmit: () {
                    _syncSourceLoadByMode();
                    _submitCalcNow();
                  },
                  action1: TextInputAction.next,
                  action2: TextInputAction.next,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Z inputs',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          lockWrap(
            enabled: zEnabled,
            child: Column(
              children: [
                ComplexInputRow(
                  format: _currentFormat,
                  ctrl1: zsC1,
                  ctrl2: zsC2,
                  paramName: 'Zs (Ω)',
                  validator: _optionalNumberValidator,
                  onAnyChanged: () {
                    _syncSourceLoadByMode();
                    _scheduleAutoCalc();
                  },
                  onSubmit: () {
                    _syncSourceLoadByMode();
                    _submitCalcNow();
                  },
                  action1: TextInputAction.next,
                  action2: TextInputAction.next,
                ),
                ComplexInputRow(
                  format: _currentFormat,
                  ctrl1: zlC1,
                  ctrl2: zlC2,
                  paramName: 'ZL (Ω)',
                  validator: _optionalNumberValidator,
                  onAnyChanged: () {
                    _syncSourceLoadByMode();
                    _scheduleAutoCalc();
                  },
                  onSubmit: () {
                    _syncSourceLoadByMode();
                    _submitCalcNow();
                  },
                  action1: TextInputAction.next,
                  action2: TextInputAction.next,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildScalarInput(
      TextEditingController controller,
      String label, {
        TextInputAction action = TextInputAction.next,
        bool optional = false,
      }) {
    return TextFormField(
      controller: controller,
      validator: optional ? _optionalNumberValidator : commonValidator,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      textInputAction: action,
      onChanged: (_) => _scheduleAutoCalc(),
      onFieldSubmitted: (_) => _submitCalcNow(),
      onEditingComplete: _submitCalcNow,
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
  void dispose() {
    _debounce?.cancel();
    freqController.dispose();
    s11C1.dispose(); s11C2.dispose();
    s12C1.dispose(); s12C2.dispose();
    s21C1.dispose(); s21C2.dispose();
    s22C1.dispose(); s22C2.dispose();

    gammaSC1.dispose(); gammaSC2.dispose();
    gammaLC1.dispose(); gammaLC2.dispose();
    zsC1.dispose(); zsC2.dispose();
    zlC1.dispose(); zlC2.dispose();
    z0C.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ex = _examples[_exampleIndex];

    return CommonScaffold(
      title: 'Amplifier Full Flow Calculator',
      body: _tapBlankToCalc(
        child: SingleChildScrollView(
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

                Card(
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 520;

                        final titleWidget = Text(
                          'Current Example: ${ex.name}  (${_exampleIndex + 1}/${_examples.length})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: isNarrow ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        );

                        final prevBtn = ElevatedButton.icon(
                          onPressed: _previousExampleAndRecalculate,
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Previous Example'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );

                        final nextBtn = ElevatedButton.icon(
                          onPressed: _nextExampleAndRecalculate,
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('Next Example'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );

                        if (!isNarrow) {
                          return Row(
                            children: [
                              Expanded(child: titleWidget),
                              const SizedBox(width: 10),
                              prevBtn,
                              const SizedBox(width: 10),
                              nextBtn,
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleWidget,
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                prevBtn,
                                nextBtn,
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                ComplexInputRow(
                  format: _currentFormat,
                  ctrl1: s11C1,
                  ctrl2: s11C2,
                  paramName: 'S11',
                  validator: commonValidator,
                  onAnyChanged: _scheduleAutoCalc,
                  onSubmit: _submitCalcNow,
                  action1: TextInputAction.next,
                  action2: TextInputAction.next,
                ),
                ComplexInputRow(
                  format: _currentFormat,
                  ctrl1: s12C1,
                  ctrl2: s12C2,
                  paramName: 'S12',
                  validator: commonValidator,
                  onAnyChanged: _scheduleAutoCalc,
                  onSubmit: _submitCalcNow,
                  action1: TextInputAction.next,
                  action2: TextInputAction.next,
                ),
                ComplexInputRow(
                  format: _currentFormat,
                  ctrl1: s21C1,
                  ctrl2: s21C2,
                  paramName: 'S21',
                  validator: commonValidator,
                  onAnyChanged: _scheduleAutoCalc,
                  onSubmit: _submitCalcNow,
                  action1: TextInputAction.next,
                  action2: TextInputAction.next,
                ),
                ComplexInputRow(
                  format: _currentFormat,
                  ctrl1: s22C1,
                  ctrl2: s22C2,
                  paramName: 'S22',
                  validator: commonValidator,
                  onAnyChanged: _scheduleAutoCalc,
                  onSubmit: _submitCalcNow,
                  action1: TextInputAction.next,
                  action2: TextInputAction.next,
                ),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),

                _buildSourceLoadSection(),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: _buildScalarInput(freqController, 'Freq (GHz)', optional: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildScalarInput(z0C, 'Z0 (Ω)', optional: true)),
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
                          title: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Math.tex(
                              entry.value.titleLatex,
                              textStyle: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isExpanded ? Colors.deepPurple : Colors.black87,
                              ),
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
      ),
    );
  }
}