import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:equations/equations.dart';

import '../functional_components/menu_functions.dart';
import '../input_and_output_functions/utils.dart';
import '../functional_components/fixed_input.dart';
import '../smith_chart_db_module/smith_gain_circle_painter.dart';

enum SourceLoadInputMode {
  gamma, // input Γs, ΓL
  impedance, // input Zs, ZL
}

// Example data model
class NoiseCircleExample {
  final String title;
  final String subtitle;

  final SourceLoadInputMode mode;
  final ComplexInputFormat preferredFormat;

  final double z0;
  final double fminDb;
  final double rnOhm;

  // Noise params
  final Complex gammaOpt;

  // Demo Γs/ΓL (book may not give; we provide for NF@Γs)
  final Complex gammaS;
  final Complex gammaL;

  // Demo Zs/ZL (for impedance mode)
  final Complex zs;
  final Complex zl;

  // Target F list (dB)
  final List<double> fTargetsDb;

  const NoiseCircleExample({
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.preferredFormat,
    required this.z0,
    required this.fminDb,
    required this.rnOhm,
    required this.gammaOpt,
    required this.gammaS,
    required this.gammaL,
    required this.zs,
    required this.zl,
    required this.fTargetsDb,
  });
}

class ConstantNoiseFigureCirclesPage extends StatefulWidget {
  const ConstantNoiseFigureCirclesPage({super.key});

  @override
  State<ConstantNoiseFigureCirclesPage> createState() =>
      _ConstantNoiseFigureCirclesPageState();
}

class _ConstantNoiseFigureCirclesPageState
    extends State<ConstantNoiseFigureCirclesPage> {
  final _formKey = GlobalKey<FormState>();

  // 防抖计时器
  Timer? _debounceTimer;

  ComplexInputFormat _currentFormat = ComplexInputFormat.polarDegree;

  final s11C1 = TextEditingController(text: '0.6');
  final s11C2 = TextEditingController(text: '-60');
  final s12C1 = TextEditingController(text: '0.05');
  final s12C2 = TextEditingController(text: '26');
  final s21C1 = TextEditingController(text: '1.9');
  final s21C2 = TextEditingController(text: '81');
  final s22C1 = TextEditingController(text: '0.5');
  final s22C2 = TextEditingController(text: '-60');

  // noise params
  final gammaOptC1 = TextEditingController(text: '0.485');
  final gammaOptC2 = TextEditingController(text: '155');
  final z0C = TextEditingController(text: '50');
  final fminC = TextEditingController(text: '2');
  final rnC = TextEditingController(text: '4');
  final fListC = TextEditingController(text: '2.5, 3.0, 3.5, 4.0, 5.0');

  SourceLoadInputMode _slMode = SourceLoadInputMode.gamma;

  // Γs, ΓL
  final gammaSC1 = TextEditingController(text: '0.2');
  final gammaSC2 = TextEditingController(text: '-30');
  final gammaLC1 = TextEditingController(text: '0.1');
  final gammaLC2 = TextEditingController(text: '20');

  // Zs, ZL
  final zSC1 = TextEditingController(text: '50');
  final zSC2 = TextEditingController(text: '0');
  final zLC1 = TextEditingController(text: '50');
  final zLC2 = TextEditingController(text: '0');

  // results state
  bool _hasCalculated = false;

  List<bool> _expandedList = [];
  List<StepPanel> _stepPanels = [];
  List<List<String>> _summaryTableData = [];
  List<GainCircleData> noiseFigureCirclePainterData = [];

  // NF for specific Γs
  double? _nfLinForGammaS;
  double? _nfDbForGammaS;

  // warnings/errors
  final List<String> _warnings = [];
  void _warn(String msg) => _warnings.add(msg);

  static const double _eps = 1e-12;

  bool _isFiniteNum(double x) => !(x.isNaN || x.isInfinite);
  bool _isFiniteComplex(Complex c) =>
      _isFiniteNum(c.real) && _isFiniteNum(c.imaginary);

  String _escapeLatexText(String s) {
    return s
        .replaceAll(r'\', r'\textbackslash{}')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}')
        .replaceAll('%', r'\%')
        .replaceAll('&', r'\&')
        .replaceAll('#', r'\#')
        .replaceAll('_', r'\_')
        .replaceAll('^', r'\^{}')
        .replaceAll('~', r'\~{}');
  }

  Widget _latexTitle(
      String title, {
        double fontSize = 16,
        FontWeight fontWeight = FontWeight.bold,
        Color color = Colors.black87,
        TextAlign textAlign = TextAlign.left,
      }) {
    final w = Math.tex(
      r'\text{' + _escapeLatexText(title) + r'}',
      textStyle: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: 1.2,
      ),
    );

    Alignment alignment;
    switch (textAlign) {
      case TextAlign.center:
        alignment = Alignment.center;
        break;
      case TextAlign.right:
      case TextAlign.end:
        alignment = Alignment.centerRight;
        break;
      case TextAlign.left:
      case TextAlign.start:
      default:
        alignment = Alignment.centerLeft;
    }

    return Align(alignment: alignment, child: w);
  }

  late final List<NoiseCircleExample> _examples = [
    NoiseCircleExample(
      title: 'Example 4-6 (2 GHz, GaAs MESFET)',
      subtitle:
      'Fmin=2 dB, Γopt=0.485∠155°, Rn=4 Ω, Z0=50 Ω, target F: 2.5/3.0/3.5/5.0 dB',
      mode: SourceLoadInputMode.gamma,
      preferredFormat: ComplexInputFormat.polarDegree,
      z0: 50,
      fminDb: 2,
      rnOhm: 4,
      gammaOpt: Complex.fromPolar(r: 0.485, theta: 155 * pi / 180),
      gammaS: Complex.fromPolar(r: 0.2, theta: -30 * pi / 180),
      gammaL: Complex.fromPolar(r: 0.1, theta: 20 * pi / 180),
      zs: Complex(50, 0),
      zl: Complex(50, 0),
      fTargetsDb: const [2.5, 3.0, 3.5, 5.0],
    ),
    NoiseCircleExample(
      title: 'Example A (Γs close to Γopt)',
      subtitle: 'NF should be close to Fmin when Γs ≈ Γopt',
      mode: SourceLoadInputMode.gamma,
      preferredFormat: ComplexInputFormat.polarDegree,
      z0: 50,
      fminDb: 1.2,
      rnOhm: 3.0,
      gammaOpt: Complex.fromPolar(r: 0.35, theta: 120 * pi / 180),
      gammaS: Complex.fromPolar(r: 0.34, theta: 118 * pi / 180),
      gammaL: Complex.fromPolar(r: 0.10, theta: -40 * pi / 180),
      zs: Complex(50, 0),
      zl: Complex(50, 0),
      fTargetsDb: const [1.5, 2.0, 2.5, 3.0],
    ),
    NoiseCircleExample(
      title: 'Example B (Larger Rn → larger circles)',
      subtitle: 'Increase Rn and see circles expand',
      mode: SourceLoadInputMode.gamma,
      preferredFormat: ComplexInputFormat.polarDegree,
      z0: 50,
      fminDb: 2.0,
      rnOhm: 10.0,
      gammaOpt: Complex.fromPolar(r: 0.45, theta: 150 * pi / 180),
      gammaS: Complex.fromPolar(r: 0.25, theta: 10 * pi / 180),
      gammaL: Complex.fromPolar(r: 0.15, theta: -20 * pi / 180),
      zs: Complex(50, 0),
      zl: Complex(50, 0),
      fTargetsDb: const [2.5, 3.0, 4.0, 5.0, 6.0],
    ),
    NoiseCircleExample(
      title: 'Example C (Impedance input mode)',
      subtitle: 'Enter Zs/ZL and auto-convert to Γs/ΓL',
      mode: SourceLoadInputMode.impedance,
      preferredFormat: ComplexInputFormat.cartesian,
      z0: 50,
      fminDb: 1.8,
      rnOhm: 5.0,
      gammaOpt: Complex.fromPolar(r: 0.40, theta: 135 * pi / 180),
      gammaS: Complex.fromPolar(r: 0.0, theta: 0.0),
      gammaL: Complex.fromPolar(r: 0.0, theta: 0.0),
      zs: Complex(60, 20),
      zl: Complex(40, -10),
      fTargetsDb: const [2.0, 2.5, 3.0, 3.5, 4.5],
    ),
  ];

  int _exampleIndex = 0;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    for (final c in [
      s11C1, s11C2, s12C1, s12C2, s21C1, s21C2, s22C1, s22C2,
      gammaOptC1, gammaOptC2, z0C, fminC, rnC, fListC,
      gammaSC1, gammaSC2, gammaLC1, gammaLC2,
      zSC1, zSC2, zLC1, zLC2,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onInputChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_formKey.currentState?.validate() ?? false) {
        _onCalculatePressed();
      }
    });
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

  double _parseZ0() {
    final z0 = double.tryParse(z0C.text) ?? 50.0;
    if (z0 <= 0 || z0.isNaN || z0.isInfinite) {
      _warn('Z0 must be positive. Fallback to 50 Ω.');
      return 50.0;
    }
    return z0;
  }

  Complex _parseComplex(TextEditingController c1, TextEditingController c2) {
    return ComplexParser.parseUniversal(_joinInput(c1, c2), _currentFormat);
  }

  // -----------------------------
  // Γ <-> Z conversions (SAFE: returns null when invalid)
  // -----------------------------
  Complex? _zToGammaSafe(Complex z, double z0) {
    if (!_isFiniteComplex(z)) return null;
    if (z0 <= 0) return null;

    final den = z + Complex(z0, 0);
    if (den.modulus < _eps) return null;

    final num = z - Complex(z0, 0);
    final g = num / den;
    return _isFiniteComplex(g) ? g : null;
  }

  Complex? _gammaToZSafe(Complex g, double z0) {
    if (!_isFiniteComplex(g)) return null;
    if (z0 <= 0) return null;

    final den = Complex(1, 0) - g;
    if (den.modulus < _eps) return null;

    final num = Complex(1, 0) + g;
    final z = Complex(z0, 0) * (num / den);
    return _isFiniteComplex(z) ? z : null;
  }

  void _setComplexToControllers(
      Complex? c,
      TextEditingController c1,
      TextEditingController c2,
      ComplexInputFormat fmt,
      ) {
    if (c == null || !_isFiniteComplex(c)) {
      c1.text = '—';
      c2.text = '—';
      return;
    }

    if (fmt == ComplexInputFormat.cartesian) {
      c1.text = ComplexFormatter.smartFormat(c.real,
          useScientific: false, precision: 6);
      c2.text = ComplexFormatter.smartFormat(c.imaginary,
          useScientific: false, precision: 6);
    } else {
      c1.text = ComplexFormatter.smartFormat(c.modulus,
          useScientific: false, precision: 6);
      final ang = (fmt == ComplexInputFormat.polarDegree)
          ? c.phase() * 180 / pi
          : c.phase();
      c2.text = ComplexFormatter.smartFormat(ang,
          useScientific: false, precision: 6);
    }
  }

  String _texNum(double v, {int precision = 4}) {
    if (v.isNaN) return r'\text{NaN}';
    if (v.isInfinite) return v.isNegative ? r'-\infty' : r'\infty';
    return ComplexFormatter.smartFormat(v, useLatex: true, precision: precision);
  }

  String _latexComplex(Complex c, {int precision = 4}) {
    if (!_isFiniteComplex(c)) return r'\text{NaN}';
    return ComplexFormatter.latexHybrid(c, precision: precision);
  }

  double? _safeDivOrNull(double num, double den) {
    if (den.abs() < _eps) return null;
    final out = num / den;
    if (out.isNaN || out.isInfinite) return null;
    return out;
  }

  void _showFormErrorSnackBar() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '❌ Input invalid. Please check the red error hints.\n'
              'Tips: Z0 > 0, |Γ| < 1 (passive source), avoid singular points like (Z + Z0) ≈ 0 or (1 − Γ) ≈ 0.',
        ),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _applyExample(NoiseCircleExample ex) {
    setState(() {
      _hasCalculated = false;
      _warnings.clear();
      _stepPanels.clear();
      _summaryTableData.clear();
      noiseFigureCirclePainterData.clear();
      _expandedList = [];

      _currentFormat = ex.preferredFormat;

      z0C.text = ComplexFormatter.smartFormat(ex.z0, precision: 6);
      fminC.text = ComplexFormatter.smartFormat(ex.fminDb, precision: 6);
      rnC.text = ComplexFormatter.smartFormat(ex.rnOhm, precision: 6);
      fListC.text =
          ex.fTargetsDb.map((e) => ComplexFormatter.smartFormat(e)).join(', ');

      _setComplexToControllers(ex.gammaOpt, gammaOptC1, gammaOptC2, _currentFormat);

      _slMode = ex.mode;
      if (_slMode == SourceLoadInputMode.gamma) {
        _setComplexToControllers(ex.gammaS, gammaSC1, gammaSC2, _currentFormat);
        _setComplexToControllers(ex.gammaL, gammaLC1, gammaLC2, _currentFormat);
      } else {
        _setComplexToControllers(ex.zs, zSC1, zSC2, _currentFormat);
        _setComplexToControllers(ex.zl, zLC1, zLC2, _currentFormat);
      }

      _syncOtherSideFromCurrentSide();
    });
  }

  void _nextExample() {
    setState(() {
      _exampleIndex = (_exampleIndex + 1) % _examples.length;
    });
    _applyExample(_examples[_exampleIndex]);
  }

  void switchAllFormat(ComplexInputFormat newFormat) {
    setState(() {
      void convert(TextEditingController c1, TextEditingController c2) {
        final c = ComplexParser.parseUniversal(_joinInput(c1, c2), _currentFormat);
        _setComplexToControllers(c, c1, c2, newFormat);
      }

      convert(s11C1, s11C2);
      convert(s12C1, s12C2);
      convert(s21C1, s21C2);
      convert(s22C1, s22C2);

      convert(gammaOptC1, gammaOptC2);
      convert(gammaSC1, gammaSC2);
      convert(gammaLC1, gammaLC2);
      convert(zSC1, zSC2);
      convert(zLC1, zLC2);

      _currentFormat = newFormat;

      if (_hasCalculated) _onCalculatePressed();
    });
  }

  void _switchSourceLoadMode(SourceLoadInputMode newMode) {
    setState(() {
      final z0 = double.tryParse(z0C.text) ?? 50.0;

      if (newMode == _slMode) return;

      if (newMode == SourceLoadInputMode.impedance) {
        final gs = _parseComplex(gammaSC1, gammaSC2);
        final gl = _parseComplex(gammaLC1, gammaLC2);
        final zs = _gammaToZSafe(gs, z0);
        final zl = _gammaToZSafe(gl, z0);
        _setComplexToControllers(zs, zSC1, zSC2, _currentFormat);
        _setComplexToControllers(zl, zLC1, zLC2, _currentFormat);
      } else {
        final zs = _parseComplex(zSC1, zSC2);
        final zl = _parseComplex(zLC1, zLC2);
        final gs = _zToGammaSafe(zs, z0);
        final gl = _zToGammaSafe(zl, z0);
        _setComplexToControllers(gs, gammaSC1, gammaSC2, _currentFormat);
        _setComplexToControllers(gl, gammaLC1, gammaLC2, _currentFormat);
      }

      _slMode = newMode;
      if (_hasCalculated) _onCalculatePressed();
    });
  }

  void _syncOtherSideFromCurrentSide() {
    final z0 = double.tryParse(z0C.text) ?? 50.0;

    if (_slMode == SourceLoadInputMode.gamma) {
      final gs = _parseComplex(gammaSC1, gammaSC2);
      final gl = _parseComplex(gammaLC1, gammaLC2);
      _setComplexToControllers(_gammaToZSafe(gs, z0), zSC1, zSC2, _currentFormat);
      _setComplexToControllers(_gammaToZSafe(gl, z0), zLC1, zLC2, _currentFormat);
    } else {
      final zs = _parseComplex(zSC1, zSC2);
      final zl = _parseComplex(zLC1, zLC2);
      _setComplexToControllers(_zToGammaSafe(zs, z0), gammaSC1, gammaSC2, _currentFormat);
      _setComplexToControllers(_zToGammaSafe(zl, z0), gammaLC1, gammaLC2, _currentFormat);
    }
  }

  void _onCalculatePressed() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      _showFormErrorSnackBar();
      return;
    }

    setState(() {
      _syncOtherSideFromCurrentSide();
      _hasCalculated = true;
      _calculateNoiseFigureResults();
    });
  }

  void _calculateNoiseFigureResults() {
    _warnings.clear();

    // 1. Parse Parameters
    final Gamma_opt = _parseComplex(gammaOptC1, gammaOptC2);
    final Z0 = _parseZ0();

    final Fmin_dB = double.tryParse(fminC.text) ?? 0.0;
    final Fmin_lin = pow(10, Fmin_dB / 10).toDouble();

    final Rn_val = double.tryParse(rnC.text) ?? 0.0;

    // rn = Rn/Z0
    final rn = (Z0 > _eps) ? (Rn_val / Z0) : double.nan;
    if (!_isFiniteNum(rn)) {
      _warn(
          'rn = Rn/Z0 is invalid (Z0 too small). Noise circles may be skipped.');
    }

    final Gamma_s = _parseComplex(gammaSC1, gammaSC2);
    final Gamma_L = _parseComplex(gammaLC1, gammaLC2);

    final Zs = _gammaToZSafe(Gamma_s, Z0);
    final Zl = _gammaToZSafe(Gamma_L, Z0);

    final gammaOptAbs2 = pow(Gamma_opt.modulus, 2).toDouble();
    final onePlusGammaOptAbs2 =
    pow((Complex(1, 0) + Gamma_opt).modulus, 2).toDouble();
    if (onePlusGammaOptAbs2 < _eps) {
      _warn(
          '|1 + Γopt| is near 0. This can cause divide-by-zero in NF formula.');
    }

    final fListDb = fListC.text
        .split(',')
        .map((e) => double.tryParse(e.trim()))
        .whereType<double>()
        .toList();

    // 2. Clear old results
    noiseFigureCirclePainterData.clear();
    _stepPanels.clear();
    _summaryTableData.clear();

    // 3. Calculation for specific Γs
    _nfLinForGammaS = null;
    _nfDbForGammaS = null;

    final gammaSAbs2 = pow(Gamma_s.modulus, 2).toDouble();
    final diffAbs2 = pow((Gamma_s - Gamma_opt).modulus, 2).toDouble();

    if (!_isFiniteNum(gammaSAbs2) || !_isFiniteNum(diffAbs2)) {
      _warn('Γs or Γopt is invalid (NaN/Inf). NF cannot be computed.');
    } else if (gammaSAbs2 >= 1.0) {
      _warn(
          '|Γs| >= 1 makes (1-|Γs|^2) <= 0. NF formula invalid for passive source.');
    } else if (!_isFiniteNum(onePlusGammaOptAbs2) ||
        onePlusGammaOptAbs2 < _eps) {
      _warn('|1 + Γopt|^2 is near 0. NF denominator is near 0.');
    } else if (!_isFiniteNum(rn) || rn.abs() < _eps) {
      if (rn.abs() < _eps) {
        _nfLinForGammaS = Fmin_lin;
        _nfDbForGammaS = Fmin_dB;
        _warn(
            'rn is ~0, NF collapses to Fmin. Noise circles will be skipped.');
      } else {
        _warn('rn is invalid. NF cannot be computed reliably.');
      }
    } else {
      final denom = (1.0 - gammaSAbs2) * onePlusGammaOptAbs2;
      final addTerm = _safeDivOrNull(4.0 * rn * diffAbs2, denom);

      if (addTerm == null) {
        _warn('NF denominator is near 0. NF cannot be computed.');
      } else {
        final F_lin_specific = Fmin_lin + addTerm;
        if (F_lin_specific <= 0 ||
            F_lin_specific.isNaN ||
            F_lin_specific.isInfinite) {
          _warn('Computed F(linear) is invalid (<=0 or NaN/Inf).');
        } else {
          final F_db_specific = 10.0 * (log(F_lin_specific) / ln10);
          if (_isFiniteNum(F_db_specific)) {
            _nfLinForGammaS = F_lin_specific;
            _nfDbForGammaS = F_db_specific;
          } else {
            _warn('Computed F(dB) is invalid (NaN/Inf).');
          }
        }
      }
    }

    // --- Panel 0: Basic Formulas & Parameters ---
    _stepPanels.add(
      StepPanel(
        title: 'Basic Formulas & Parameters',
        content: [
          _latexTitle('Noise Figure Formula (in terms of Γs):',
              fontSize: 14, color: Colors.black87),
          _texScroll(
              r'F = F_{\min} + \frac{4 r_n |\Gamma_s - \Gamma_{opt}|^2}{ (1 - |\Gamma_s|^2)\, |1 + \Gamma_{opt}|^2 }'),
          _latexTitle('Given Noise Parameters:', fontSize: 14),
          _texScroll(
              r'Z_0 = ' + ComplexFormatter.smartFormat(Z0) + r' \Omega'),
          _texScroll(r'R_n = ' +
              ComplexFormatter.smartFormat(Rn_val) +
              r' \Omega \Rightarrow r_n = \frac{R_n}{Z_0} = ' +
              ComplexFormatter.smartFormat(rn)),
          _texScroll(r'F_{\min} = ' +
              ComplexFormatter.smartFormat(Fmin_dB) +
              r' \text{ dB} \Rightarrow F_{\min,lin} = ' +
              ComplexFormatter.smartFormat(Fmin_lin)),
          // 使用当前格式显示 Γopt
          _texScroll(r'\Gamma_{opt} = ' +
              ComplexFormatter.latex(Gamma_opt, _currentFormat, precision: 4)),
          const Divider(),
          _latexTitle('Source/Load Representations:', fontSize: 14),
          // Γs
          _texScroll(r'\Gamma_s = ' +
              ComplexFormatter.latex(Gamma_s, _currentFormat, precision: 4)),
          // Zs
          _texScroll(r'Z_s = ' +
              (Zs == null
                  ? r'\text{—}'
                  : ComplexFormatter.latex(Zs, _currentFormat, precision: 4)) +
              r'\ \Omega'),
          // 【新增】 ΓL
          _texScroll(r'\Gamma_L = ' +
              ComplexFormatter.latex(Gamma_L, _currentFormat, precision: 4)),
          // 【新增】 ZL
          _texScroll(r'Z_L = ' +
              (Zl == null
                  ? r'\text{—}'
                  : ComplexFormatter.latex(Zl, _currentFormat, precision: 4)) +
              r'\ \Omega'),
          if (_warnings.isNotEmpty) ...[
            const Divider(),
            _latexTitle('Warnings:', fontSize: 14, color: Colors.red),
            ..._warnings.map((w) => _text('• $w')),
          ],
        ],
      ),
    );

    // --- Panel 1: Specific Γs -> F result (Detailed Substitution) ---
    final String strGammaS =
    ComplexFormatter.latex(Gamma_s, _currentFormat, precision: 3);
    final String strGammaOpt =
    ComplexFormatter.latex(Gamma_opt, _currentFormat, precision: 3);
    final String strNumDiffSub =
        r'|' + strGammaS + r' - ' + strGammaOpt + r'|^2';
    final String strDenom1Sub = r'(1 - |' + strGammaS + r'|^2)';
    final String strDenom2Sub = r'|1 + ' + strGammaOpt + r'|^2';
    final String strFminLin = _texNum(Fmin_lin, precision: 4);
    final String strRn = _texNum(rn, precision: 4);

    _stepPanels.add(
      StepPanel(
        title: 'Noise Figure at your Γs',
        content: [
          _latexTitle('1. General Formula',
              fontSize: 14, fontWeight: FontWeight.bold),
          _texScroll(
              r'F = F_{\min} + \frac{4 r_n |\Gamma_s - \Gamma_{opt}|^2}{ (1 - |\Gamma_s|^2)\, |1 + \Gamma_{opt}|^2 }'),
          const SizedBox(height: 8),
          _latexTitle('2. Parameter Substitution',
              fontSize: 14, fontWeight: FontWeight.bold),
          _text('Using values in selected format:'),
          _texScroll(r'\Gamma_s = ' + strGammaS),
          _texScroll(r'\Gamma_{opt} = ' + strGammaOpt),
          _texScroll(
              r'F_{\min,lin} = ' + strFminLin + r',\quad r_n = ' + strRn),
          const SizedBox(height: 8),
          _latexTitle('3. Final Substitution (No Calculation)',
              fontSize: 14, fontWeight: FontWeight.bold),
          _texScroll(r'F = ' +
              strFminLin +
              r' + \frac{4 \cdot ' +
              strRn +
              r' \cdot ' +
              strNumDiffSub +
              r'}{' +
              strDenom1Sub +
              strDenom2Sub +
              r'}'),
          const Divider(),
          _latexTitle('4. Result', fontSize: 14, fontWeight: FontWeight.bold),
          _texScroll(r'F_{lin} = ' +
              (_nfLinForGammaS == null
                  ? r'\text{NaN}'
                  : _texNum(_nfLinForGammaS!, precision: 6))),
          _texScroll(r'F_{dB} = \mathbf{' +
              (_nfDbForGammaS == null
                  ? r'\text{NaN}'
                  : _texNum(_nfDbForGammaS!, precision: 4)) +
              r' \text{ dB}}'),
        ],
      ),
    );

    // --- Noise Figure circles (guarded) ---
    if (!_isFiniteNum(rn) || rn.abs() < _eps) {
      _warn('Noise circles skipped because rn is invalid.');
    } else {
      for (int i = 0; i < fListDb.length; i++) {
        final Fi_db = fListDb[i];
        final Fi_lin = pow(10, Fi_db / 10).toDouble();

        final denomNi = 4 * rn;
        final frac = _safeDivOrNull((Fi_lin - Fmin_lin), denomNi);
        if (frac == null) continue;

        final Ni = frac * onePlusGammaOptAbs2;
        final onePlusNi = 1 + Ni;

        if (onePlusNi.abs() < _eps) continue;
        final CFi = Gamma_opt / Complex(onePlusNi, 0);
        if (!_isFiniteComplex(CFi)) continue;

        final numerator = Ni * Ni + Ni * (1 - gammaOptAbs2);
        double rFi;
        if (numerator < 0) {
          rFi = 0.0;
        } else {
          rFi = sqrt(numerator) / onePlusNi;
        }

        noiseFigureCirclePainterData.add(
          GainCircleData(
            center: CFi,
            radius: rFi,
            color: Colors.blueAccent,
            label: '${ComplexFormatter.smartFormat(Fi_db)}dB',
          ),
        );

        _summaryTableData.add([
          ComplexFormatter.smartFormat(Fi_db),
          ComplexFormatter.smartFormat(Ni, precision: 4),
          ComplexFormatter.universal(CFi, _currentFormat, precision: 3),
          ComplexFormatter.smartFormat(rFi, precision: 4),
        ]);

        final strFiLin = _texNum(Fi_lin, precision: 3);
        final strFminLinForLoop = _texNum(Fmin_lin, precision: 3);
        final strRnForLoop = _texNum(rn, precision: 3);
        final strNi = _texNum(Ni, precision: 4);

        final strGammaOptCurrent =
        ComplexFormatter.latex(Gamma_opt, _currentFormat, precision: 3);

        final strOnePlusGammaOptSqSub = r'|1 + ' + strGammaOptCurrent + r'|^2';
        final strOnePlusNiSub = r'(1 + ' + strNi + r')';
        final strRadiusNumeratorSub =
            strNi + r'^2 + ' + strNi + r'(1 - |' + strGammaOptCurrent + r'|^2)';

        _stepPanels.add(
          StepPanel(
            title:
            'Noise Circle for F = ${ComplexFormatter.smartFormat(Fi_db)} dB',
            content: [
              _latexTitle('1) Convert F to linear',
                  fontSize: 14, fontWeight: FontWeight.bold),
              _texScroll(r'F = 10^{(' +
                  ComplexFormatter.smartFormat(Fi_db) +
                  r'/10)} = ' +
                  strFiLin),
              const Divider(),
              _latexTitle('2) Calculate parameter Ni',
                  fontSize: 14, fontWeight: FontWeight.bold),
              _texScroll(
                  r'N_i = \frac{F - F_{\min}}{4 r_n}\, |1 + \Gamma_{opt}|^2'),
              // Substitution (Detailed)
              _texScroll(r'N_i = \frac{' +
                  strFiLin +
                  r' - ' +
                  strFminLinForLoop +
                  r'}{4(' +
                  strRnForLoop +
                  r')} \cdot ' +
                  strOnePlusGammaOptSqSub),
              // Result
              _texScroll(r'N_i = ' + strNi),
              const Divider(),
              _latexTitle('3) Circle Center (C)',
                  fontSize: 14, fontWeight: FontWeight.bold),
              _texScroll(r'C_{Fi} = \frac{\Gamma_{opt}}{1 + N_i}'),
              _texScroll(r'C_{Fi} = \frac{' +
                  strGammaOptCurrent +
                  r'}{' +
                  strOnePlusNiSub +
                  r'}'),
              _texScroll(r'C_{Fi} = ' +
                  ComplexFormatter.latex(CFi, _currentFormat, precision: 4)),
              const Divider(),
              _latexTitle('4) Circle Radius (R)',
                  fontSize: 14, fontWeight: FontWeight.bold),
              _texScroll(
                  r'R_{Fi} = \frac{\sqrt{N_i^2 + N_i(1 - |\Gamma_{opt}|^2)}}{1 + N_i}'),
              _texScroll(r'R_{Fi} = \frac{\sqrt{' +
                  strRadiusNumeratorSub +
                  r'}}{' +
                  strOnePlusNiSub +
                  r'}'),
              _texScroll(r'R_{Fi} = ' + _texNum(rFi, precision: 5)),
            ],
          ),
        );
      }
    }

    if (_expandedList.length != _stepPanels.length) {
      _expandedList = List.generate(_stepPanels.length, (index) => false);
    }
  }

  // Validators (page-local)
  String? _requiredNum(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (double.tryParse(v.trim()) == null) return 'Num Only';
    return null;
  }

  String? _z0Validator(String? v) {
    final base = _requiredNum(v);
    if (base != null) return base;
    final x = double.parse(v!.trim());
    if (!x.isFinite || x <= 0) return 'Z0 must be > 0';
    return null;
  }

  String? _rnValidator(String? v) {
    final base = _requiredNum(v);
    if (base != null) return base;
    final x = double.parse(v!.trim());
    if (!x.isFinite || x < 0) return 'Rn must be ≥ 0';
    return null;
  }

  String? _fListValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final parts = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    if (parts.isEmpty) return 'Required';
    final fmin = double.tryParse(fminC.text.trim()) ?? 0.0;
    for (final p in parts) {
      final x = double.tryParse(p);
      if (x == null) return 'Invalid list';
      if (!x.isFinite) return 'Invalid list';
      if (x < fmin) return 'Each F must be ≥ Fmin';
    }
    return null;
  }

  // Γ row validator: |Γ|<1
  String? _gammaRowValidator(TextEditingController c1, TextEditingController c2) {
    final a = c1.text.trim();
    final b = c2.text.trim();
    if (a.isEmpty || b.isEmpty) return 'Required';
    if (double.tryParse(a) == null || double.tryParse(b) == null) return 'Num Only';

    if (_currentFormat != ComplexInputFormat.cartesian) {
      final mag = double.tryParse(a) ?? 0.0;
      if (!mag.isFinite) return 'Invalid';
      if (mag < 0) return 'Mag must be ≥ 0';
    }

    final g = _parseComplex(c1, c2);
    final abs2 = pow(g.modulus, 2).toDouble();
    if (!_isFiniteNum(abs2)) return 'Invalid';
    if (abs2 >= 1.0) return '|Γ| must be < 1';
    return null;
  }

  // Z row validator: avoid Z≈-Z0
  String? _zRowValidator(TextEditingController c1, TextEditingController c2) {
    final a = c1.text.trim();
    final b = c2.text.trim();
    if (a.isEmpty || b.isEmpty) return 'Required';
    if (double.tryParse(a) == null || double.tryParse(b) == null) return 'Num Only';

    if (_currentFormat != ComplexInputFormat.cartesian) {
      final mag = double.tryParse(a) ?? 0.0;
      if (!mag.isFinite) return 'Invalid';
      if (mag < 0) return 'Mag must be ≥ 0';
    }

    final z0 = double.tryParse(z0C.text.trim()) ?? 50.0;
    if (z0.isFinite && z0 > 0) {
      final z = _parseComplex(c1, c2);
      final den = z + Complex(z0, 0);
      if (den.modulus < 1e-9) return 'Avoid Z ≈ -Z0 (singular)';
    }

    return null;
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
      padding: const EdgeInsets.only(bottom: 4),
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
      child: _latexTitle(
        text,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildScalarInput(
      TextEditingController controller,
      String label, {
        String? hint,
        String? Function(String?)? validator,
        VoidCallback? onChangedHook,
        VoidCallback? onSubmit,
        TextInputAction action = TextInputAction.next,
      }) {
    return TextFormField(
      controller: controller,
      validator: validator ?? _requiredNum,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      textInputAction: action,
      onChanged: (_) {
        onChangedHook?.call();
        _onInputChanged(); // 触发防抖
      },
      onFieldSubmitted: (_) => onSubmit?.call(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        isDense: true,
      ),
    );
  }

  Widget _buildComplexRow({
    required String paramName,
    required TextEditingController ctrl1,
    required TextEditingController ctrl2,
    required String label1Text,
    required String label2Text,
    required String middleSymbol,
    String? suffix2,
    required String? Function(String?) validator1,
    required String? Function(String?) validator2,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(
              width: 78,
              child: _latexTitle(
                paramName,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: ctrl1,
              validator: validator1,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: label1Text,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                errorStyle: const TextStyle(height: 0.8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: _latexTitle(
              middleSymbol,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: ctrl2,
              validator: validator2,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: label2Text,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                suffixText: suffix2,
                suffixStyle: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
                errorStyle: const TextStyle(height: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _complexRowAutoLabels({
    required String paramName,
    required TextEditingController c1,
    required TextEditingController c2,
    required String? Function(String?) validatorPair,
  }) {
    String label1Text;
    String label2Text;
    String middleSymbol;
    String? suffix2;

    switch (_currentFormat) {
      case ComplexInputFormat.cartesian:
        label1Text = 'Real';
        label2Text = 'Imag';
        middleSymbol = '+';
        suffix2 = 'j';
        break;
      case ComplexInputFormat.polarDegree:
        label1Text = 'Mag';
        label2Text = 'Ang';
        middleSymbol = '∠';
        suffix2 = '°';
        break;
      case ComplexInputFormat.polarRadian:
        label1Text = 'Mag';
        label2Text = 'Rad';
        middleSymbol = '∠';
        suffix2 = 'rad';
        break;
    }

    return _buildComplexRow(
      paramName: paramName,
      ctrl1: c1,
      ctrl2: c2,
      label1Text: label1Text,
      label2Text: label2Text,
      middleSymbol: middleSymbol,
      suffix2: suffix2,
      validator1: (_) => validatorPair(null),
      validator2: (_) => validatorPair(null),
    );
  }

  Widget _buildSummaryTable() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _latexTitle(
              "Results Summary (Noise Circles)",
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                columns: [
                  DataColumn(
                    label: _latexTitle('F (dB)',
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  DataColumn(
                    label: _latexTitle('Parameter Ni',
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  DataColumn(
                    label: _latexTitle('Center (C)',
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  DataColumn(
                    label: _latexTitle('Radius (R)',
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
                rows: _summaryTableData.map((row) {
                  return DataRow(cells: [
                    DataCell(Text(row[0],
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(row[1])),
                    DataCell(Text(row[2])),
                    DataCell(Text(row[3])),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNfCard() {
    final lin = _nfLinForGammaS;
    final db = _nfDbForGammaS;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _latexTitle(
              "Noise Figure at your Γs",
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 8),
            Text(
              "F (linear): ${lin == null ? 'NaN' : ComplexFormatter.smartFormat(lin, precision: 6)}",
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              "F (dB): ${db == null ? 'NaN' : ComplexFormatter.smartFormat(db, precision: 6)} dB",
              style: const TextStyle(fontSize: 14),
            ),
            if (_warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              _latexTitle("Warnings:", fontSize: 14, fontWeight: FontWeight.bold),
              const SizedBox(height: 4),
              ..._warnings.map((w) => Text("• $w")),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modeToggle() {
    final isGamma = _slMode == SourceLoadInputMode.gamma;
    return Row(
      children: [
        _latexTitle("Input Mode:", fontSize: 14, fontWeight: FontWeight.bold),
        const SizedBox(width: 10),
        ToggleButtons(
          borderRadius: BorderRadius.circular(8),
          isSelected: [isGamma, !isGamma],
          onPressed: (idx) {
            if (idx == 0) {
              _switchSourceLoadMode(SourceLoadInputMode.gamma);
            } else {
              _switchSourceLoadMode(SourceLoadInputMode.impedance);
            }
          },
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _latexTitle("Γs & ΓL",
                  fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _latexTitle("Zs & ZL",
                  fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _blockReadOnly({required bool readOnly, required Widget child}) {
    if (!readOnly) return child;
    return Opacity(
      opacity: 0.65,
      child: IgnorePointer(child: child),
    );
  }

  Widget _exampleHeader() {
    final ex = _examples[_exampleIndex];
    return Column(
      children: [
        // blue hint bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Noise Circles Mode — Uses noise parameters (Fmin, Γopt, Rn) to draw constant noise figure circles.",
                  style: TextStyle(color: Colors.blue[800], fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // example row + next button
        Row(
          children: [
            Expanded(
              child: _latexTitle(
                "Current Example: ${ex.title}  (${_exampleIndex + 1}/${_examples.length})",
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _nextExample,
              icon: const Icon(Icons.loop),
              label: _latexTitle("Next Example",
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            ex.subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyExample(_examples[_exampleIndex]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gammaEditable = _slMode == SourceLoadInputMode.gamma;
    final zEditable = _slMode == SourceLoadInputMode.impedance;

    return CommonScaffold(
      title: 'Constant Noise Figure Circles',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _exampleHeader(),

              // Complex format switch
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFormatBtn('Cartesian', ComplexInputFormat.cartesian),
                    const SizedBox(width: 8),
                    _buildFormatBtn('Polar (°)', ComplexInputFormat.polarDegree),
                    const SizedBox(width: 8),
                    _buildFormatBtn('Polar (rad)', ComplexInputFormat.polarRadian),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mode toggle
              _modeToggle(),
              const SizedBox(height: 12),

              // Source/Load Inputs
              _latexTitle('Source / Load Inputs:',
                  fontSize: 16, fontWeight: FontWeight.bold),
              const SizedBox(height: 8),

              // Γ inputs
              _blockReadOnly(
                readOnly: !gammaEditable,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _latexTitle('Γ inputs',
                        fontSize: 14, fontWeight: FontWeight.bold),
                    const SizedBox(height: 6),
                    ComplexInputRow(
                      format: _currentFormat,
                      ctrl1: gammaSC1, ctrl2: gammaSC2,
                      paramName: 'Γs',
                      validator: (v) => _gammaRowValidator(gammaSC1, gammaSC2),
                      onAnyChanged: _onInputChanged,
                      onSubmit: _onCalculatePressed,
                      action1: TextInputAction.next, action2: TextInputAction.next,
                    ),
                    ComplexInputRow(
                      format: _currentFormat,
                      ctrl1: gammaLC1, ctrl2: gammaLC2,
                      paramName: 'ΓL',
                      validator: (v) => _gammaRowValidator(gammaLC1, gammaLC2),
                      onAnyChanged: _onInputChanged,
                      onSubmit: _onCalculatePressed,
                      action1: TextInputAction.next, action2: TextInputAction.next,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Z inputs
              _blockReadOnly(
                readOnly: !zEditable,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _latexTitle('Z inputs',
                        fontSize: 14, fontWeight: FontWeight.bold),
                    const SizedBox(height: 6),
                    ComplexInputRow(
                      format: _currentFormat,
                      ctrl1: zSC1, ctrl2: zSC2,
                      paramName: 'Zs (Ω)',
                      validator: (v) => _zRowValidator(zSC1, zSC2),
                      onAnyChanged: _onInputChanged,
                      onSubmit: _onCalculatePressed,
                      action1: TextInputAction.next, action2: TextInputAction.next,
                    ),
                    ComplexInputRow(
                      format: _currentFormat,
                      ctrl1: zLC1, ctrl2: zLC2,
                      paramName: 'ZL (Ω)',
                      validator: (v) => _zRowValidator(zLC1, zLC2),
                      onAnyChanged: _onInputChanged,
                      onSubmit: _onCalculatePressed,
                      action1: TextInputAction.next, action2: TextInputAction.next,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Noise Parameters
              _latexTitle('Noise Parameters:',
                  fontSize: 16, fontWeight: FontWeight.bold),
              const SizedBox(height: 8),

              // Γopt
              ComplexInputRow(
                format: _currentFormat,
                ctrl1: gammaOptC1, ctrl2: gammaOptC2,
                paramName: 'Γopt',
                validator: (v) => _gammaRowValidator(gammaOptC1, gammaOptC2),
                onAnyChanged: _onInputChanged,
                onSubmit: _onCalculatePressed,
                action1: TextInputAction.next, action2: TextInputAction.next,
              ),

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildScalarInput(
                      fminC,
                      'Fmin (dB)',
                      validator: _requiredNum,
                      onSubmit: _onCalculatePressed,
                      action: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildScalarInput(
                      rnC,
                      'Rn (Ω)',
                      validator: _rnValidator,
                      onSubmit: _onCalculatePressed,
                      action: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildScalarInput(
                      z0C,
                      'Z0 (Ω)',
                      validator: _z0Validator,
                      onChangedHook: () {
                        _syncOtherSideFromCurrentSide();
                        // 触发防抖
                      },
                      onSubmit: _onCalculatePressed,
                      action: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: fListC,
                      validator: _fListValidator,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => _onInputChanged(),
                      onFieldSubmitted: (_) => _onCalculatePressed(),
                      decoration: const InputDecoration(
                        labelText: 'Target F (dB)',
                        border: OutlineInputBorder(),
                        contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _onCalculatePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calculate),
                      const SizedBox(width: 8),
                      _latexTitle(
                        'Calculate',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              if (_hasCalculated) ...[
                // circles visualization
                if (noiseFigureCirclePainterData.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 5,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        _latexTitle(
                          "Visualization (Noise Circles)",
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 350,
                          child: SmithGainCirclePainter(
                            gainCircles: noiseFigureCirclePainterData,
                            canvasSize: 350,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_summaryTableData.isNotEmpty) _buildSummaryTable(),
                const SizedBox(height: 12),

                _buildNfCard(),

                const SizedBox(height: 20),
                _latexTitle(
                  "Detailed Derivation:",
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                const SizedBox(height: 10),

                ExpansionPanelList(
                  expansionCallback: (panelIndex, isExpanded) {
                    setState(() {
                      _expandedList[panelIndex] = !_expandedList[panelIndex];
                    });
                  },
                  children: _stepPanels.asMap().entries.map((entry) {
                    return ExpansionPanel(
                      headerBuilder: (context, isExpanded) => ListTile(
                        title: _latexTitle(
                          entry.value.title,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isExpanded ? Colors.deepPurple : Colors.black87,
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
                      isExpanded: _expandedList[entry.key],
                      canTapOnHeader: true,
                    );
                  }).toList(),
                  elevation: 1,
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

// Step panel data structure
class StepPanel {
  final String title;
  final List<Widget> content;
  StepPanel({required this.title, required this.content});
}