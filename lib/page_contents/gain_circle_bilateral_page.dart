import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:equations/equations.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../functional_components/menu_functions.dart';
import '../input_and_output_functions/utils.dart';
import '../functional_components/fixed_input.dart';
import '../smith_chart_db_module/smith_gain_circle_painter.dart';

// Simple data structure: Step panels
class StepPanel {
  final String title;
  final List<Widget> content;
  StepPanel({required this.title, required this.content});
}

// Example data structure
class GainCircleExample {
  final String name;

  // Store in Polar(Degree) as the canonical representation
  final double s11Mag, s11AngDeg;
  final double s12Mag, s12AngDeg;
  final double s21Mag, s21AngDeg;
  final double s22Mag, s22AngDeg;

  final double z0;
  final String gainDbList; // e.g. "6, 8, 10"

  const GainCircleExample({
    required this.name,
    required this.s11Mag,
    required this.s11AngDeg,
    required this.s12Mag,
    required this.s12AngDeg,
    required this.s21Mag,
    required this.s21AngDeg,
    required this.s22Mag,
    required this.s22AngDeg,
    this.z0 = 50,
    this.gainDbList = '6, 8, 10',
  });

  Complex get S11 => Complex.fromPolar(r: s11Mag, theta: s11AngDeg * pi / 180.0);
  Complex get S12 => Complex.fromPolar(r: s12Mag, theta: s12AngDeg * pi / 180.0);
  Complex get S21 => Complex.fromPolar(r: s21Mag, theta: s21AngDeg * pi / 180.0);
  Complex get S22 => Complex.fromPolar(r: s22Mag, theta: s22AngDeg * pi / 180.0);
}

// Cases (A/B/C)
enum BilateralCase { a, b, c }

class CaseInfo {
  final BilateralCase which;
  final String title;
  final String rule;
  final String maxGainRule;
  final String conjMatchRule;

  const CaseInfo({
    required this.which,
    required this.title,
    required this.rule,
    required this.maxGainRule,
    required this.conjMatchRule,
  });
}

class GainCircleBilateralPage extends StatefulWidget {
  const GainCircleBilateralPage({super.key});

  @override
  State<GainCircleBilateralPage> createState() => _GainCircleBilateralPageState();
}

class _GainCircleBilateralPageState extends State<GainCircleBilateralPage> {
  final _formKey = GlobalKey<FormState>();

  // 防抖计时器
  Timer? _debounceTimer;

  ComplexInputFormat _currentFormat = ComplexInputFormat.polarDegree;

  // Inputs
  final s11C1 = TextEditingController();
  final s11C2 = TextEditingController();
  final s12C1 = TextEditingController();
  final s12C2 = TextEditingController();
  final s21C1 = TextEditingController();
  final s21C2 = TextEditingController();
  final s22C1 = TextEditingController();
  final s22C2 = TextEditingController();
  final z0C = TextEditingController(text: '50');
  final gainDbListC = TextEditingController(text: '6, 8, 10');

  // State
  bool _hasCalculated = false;

  List<bool> _expandedList = [];
  final List<StepPanel> _stepPanels = [];
  final List<List<String>> _summaryTableData = [];
  final List<GainCircleData> gainCirclesData = [];
  bool _isUnconditionallyStable = false;

  // Teaching case selection
  BilateralCase _case = BilateralCase.c;
  late CaseInfo _caseInfo;

  // Examples
  late final List<GainCircleExample> _examples;
  int _exampleIndex = 0;

  static const double _eps = 1e-9;

  @override
  void initState() {
    super.initState();

    _examples = const [
      // ======= Dedicated teaching samples (A/B/C) =======
      GainCircleExample(
        name: 'Teaching Sample - Case A (K>1, |Δ|<1)',
        s11Mag: 0.005333331053280299,
        s11AngDeg: -38.23132632891036,
        s12Mag: 0.15877642161044378,
        s12AngDeg: 10.332161707329702,
        s21Mag: 1.7838475067950121,
        s21AngDeg: -154.65892070881674,
        s22Mag: 0.5112905094584991,
        s22AngDeg: 165.3928323974535,
        z0: 50,
        gainDbList: '6, 8, 10',
      ),
      GainCircleExample(
        name: 'Teaching Sample - Case B (K>1, |Δ|>1)',
        s11Mag: 0.31350583684000877,
        s11AngDeg: 158.25109965540858,
        s12Mag: 0.26898980163072633,
        s12AngDeg: -136.15455650164674,
        s21Mag: 3.817668213060078,
        s21AngDeg: 143.60729164623066,
        s22Mag: 0.3044388976539827,
        s22AngDeg: 10.154204316002625,
        z0: 50,
        gainDbList: '6, 9, 12',
      ),
      GainCircleExample(
        name: 'Teaching Sample - Case C (K≤1)',
        s11Mag: 0.4154764513554809,
        s11AngDeg: 4.370334179255202,
        s12Mag: 0.16053838809990534,
        s12AngDeg: -12.954994872533636,
        s21Mag: 3.6674285236018895,
        s21AngDeg: 17.87816867473057,
        s22Mag: 0.24103238131579793,
        s22AngDeg: -32.223912896382245,
        z0: 50,
        gainDbList: '6, 10, 14',
      ),

      // ======= Your original examples =======
      GainCircleExample(
        name: 'Example 4-4 (1.8 GHz, Bilateral)',
        s11Mag: 0.26, s11AngDeg: -55,
        s12Mag: 0.08, s12AngDeg: 80,
        s21Mag: 2.14, s21AngDeg: 65,
        s22Mag: 0.82, s22AngDeg: -30,
        z0: 50,
        gainDbList: '6, 8, 10',
      ),
      GainCircleExample(
        name: 'Example 4-5 (8 GHz, Bilateral)',
        s11Mag: 0.5, s11AngDeg: -180,
        s12Mag: 0.08, s12AngDeg: 30,
        s21Mag: 2.5, s21AngDeg: 70,
        s22Mag: 0.8, s22AngDeg: -100,
        z0: 50,
        gainDbList: '10',
      ),
      GainCircleExample(
        name: 'Example (Pozar 11.4 style)',
        s11Mag: 0.6, s11AngDeg: -60,
        s12Mag: 0.05, s12AngDeg: 26,
        s21Mag: 1.9, s21AngDeg: 81,
        s22Mag: 0.5, s22AngDeg: -60,
        z0: 50,
        gainDbList: '6, 8, 10',
      ),
      GainCircleExample(
        name: 'Extra Example (Low feedback)',
        s11Mag: 0.35, s11AngDeg: -20,
        s12Mag: 0.02, s12AngDeg: 110,
        s21Mag: 3.2, s21AngDeg: 40,
        s22Mag: 0.55, s22AngDeg: -75,
        z0: 50,
        gainDbList: '5, 8, 11',
      ),
      GainCircleExample(
        name: 'Extra Example (Potentially Unstable)',
        s11Mag: 0.85, s11AngDeg: -160,
        s12Mag: 0.12, s12AngDeg: 60,
        s21Mag: 1.8, s21AngDeg: 25,
        s22Mag: 0.9, s22AngDeg: -120,
        z0: 50,
        gainDbList: '3, 6, 9',
      ),
    ];

    _applyExample(_examples[_exampleIndex], autoCalculate: false);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel(); // 清除 Timer
    s11C1.dispose();
    s11C2.dispose();
    s12C1.dispose();
    s12C2.dispose();
    s21C1.dispose();
    s21C2.dispose();
    s22C1.dispose();
    s22C2.dispose();
    z0C.dispose();
    gainDbListC.dispose();
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

  void _applyExample(GainCircleExample ex, {required bool autoCalculate}) {
    setState(() {
      _setComplexControllers(s11C1, s11C2, ex.S11);
      _setComplexControllers(s12C1, s12C2, ex.S12);
      _setComplexControllers(s21C1, s21C2, ex.S21);
      _setComplexControllers(s22C1, s22C2, ex.S22);

      z0C.text = ComplexFormatter.smartFormat(ex.z0, useScientific: false, precision: 6);
      gainDbListC.text = ex.gainDbList;

      _hasCalculated = false;
      _stepPanels.clear();
      _summaryTableData.clear();
      gainCirclesData.clear();
      _expandedList = [];
    });

    if (autoCalculate) {
      _onCalculatePressed();
    }
  }

  void _nextExample() {
    setState(() {
      _exampleIndex = (_exampleIndex + 1) % _examples.length;
    });
    _applyExample(_examples[_exampleIndex], autoCalculate: true);
  }

  // Format switching
  void switchAllFormat(ComplexInputFormat newFormat) {
    if (newFormat == _currentFormat) return;

    setState(() {
      void convert(TextEditingController c1, TextEditingController c2) {
        final c = ComplexParser.parseUniversal(_joinInput(c1, c2), _currentFormat);
        if (newFormat == ComplexInputFormat.cartesian) {
          c1.text = ComplexFormatter.smartFormat(c.real, useScientific: false, precision: 6);
          c2.text = ComplexFormatter.smartFormat(c.imaginary, useScientific: false, precision: 6);
        } else {
          c1.text = ComplexFormatter.smartFormat(c.modulus, useScientific: false, precision: 6);
          double angle = (newFormat == ComplexInputFormat.polarDegree) ? c.phase() * 180 / pi : c.phase();
          c2.text = ComplexFormatter.smartFormat(angle, useScientific: false, precision: 6);
        }
      }

      convert(s11C1, s11C2);
      convert(s12C1, s12C2);
      convert(s21C1, s21C2);
      convert(s22C1, s22C2);

      _currentFormat = newFormat;
      if (_hasCalculated) _onCalculatePressed();
    });
  }

  String _texNumSafe(double val) {
    if (val.isNaN) return r'\text{undefined}';
    if (val.isInfinite) return val.isNegative ? r'-\infty' : r'\infty';
    return ComplexFormatter.smartFormat(val, useLatex: true);
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
    final isSelected = _currentFormat == fmt;
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
        String? Function(String?)? validator,
        VoidCallback? onAnyChanged,
        VoidCallback? onSubmit,
        TextInputAction action = TextInputAction.next,
      }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: action,
      onChanged: (_) => onAnyChanged?.call(),
      onFieldSubmitted: (_) => onSubmit?.call(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        isDense: true,
      ),
    );
  }

  Widget _buildExampleBar() {
    final ex = _examples[_exampleIndex];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                children: [
                  const TextSpan(
                    text: 'Current Example: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: ex.name),
                  TextSpan(
                    text: '  (${_exampleIndex + 1}/${_examples.length})',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _nextExample,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Next Example'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ),
        ],
      ),
    );
  }

  String _escapeLatexText(String s) {
    return s
        .replaceAll(r'\', r'\\')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}')
        .replaceAll('_', r'\_')
        .replaceAll('^', r'\^{}')
        .replaceAll('#', r'\#')
        .replaceAll('%', r'\%')
        .replaceAll('&', r'\&')
        .replaceAll(r'$', r'\$');
  }

  String? _panelTitleLatex(String title) {
    if (title.startsWith('0.')) {
      return r'\mathbf{0.}\ \text{Case Selection (A / B / C)}';
    }
    if (title.startsWith('1.')) {
      return r'\mathbf{1.}\ \text{Stability}\ (\Delta,\ K,\ K_t,\ \mu,\ \mu^\prime)';
    }
    if (title.startsWith('2.')) {
      final rest = title.substring(2).trim();
      return r'\mathbf{2.}\ \text{' + _escapeLatexText(rest) + r'}';
    }
    if (title.startsWith('3.')) {
      final rest = title.substring(2).trim();
      return r'\mathbf{3.}\ \text{' + _escapeLatexText(rest) + r'}';
    }
    if (title.startsWith('4.')) {
      return r'\mathbf{4.}\ \text{Simultaneous Conjugate Match}\ (\Gamma_{Ms},\ \Gamma_{ML})\ \text{— Case-based}';
    }
    return null;
  }

  Widget _panelHeaderTitle(String title, {required Color color}) {
    final latex = _panelTitleLatex(title);
    if (latex == null) {
      return Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        latex,
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  double _safeDivideToInfinity(double numerator, double denominatorAbs) {
    if (denominatorAbs < _eps) {
      if (numerator.abs() < _eps) return double.nan; // 0/0 -> undefined
      return numerator > 0 ? double.infinity : double.negativeInfinity;
    }
    return numerator / denominatorAbs;
  }

  String _infExplain(String name, double numerator, double denomAbs) {
    if (denomAbs >= _eps) return '';
    if (numerator.abs() < _eps) return '$name: denominator≈0 and numerator≈0 → undefined (0/0).';
    return '$name: denominator≈0 → ${numerator > 0 ? "+∞" : "-∞"} (sign decided by numerator).';
  }

  // choose A/B/C based on computed K & |Δ|
  CaseInfo _decideCase({required double K, required double deltaAbs, required bool stableKDelta}) {
    // Case A: unconditionally stable (classic)
    if (stableKDelta) {
      return const CaseInfo(
        which: BilateralCase.a,
        title: 'Case A (Unconditionally Stable)',
        rule: r'K > 1 \quad \text{and} \quad |\Delta| < 1',
        maxGainRule: r'\text{Use MAG: } MAG = MSG \cdot \left(K - \sqrt{K^2-1}\right)',
        conjMatchRule: r'\text{Use minus sign: } \Gamma_S = \Gamma_{Ms-},\; \Gamma_L = \Gamma_{ML-}',
      );
    }

    // Case C: special teaching branch when K ≤ 1
    if (K.isNaN || (K.isFinite && K <= 1)) {
      return const CaseInfo(
        which: BilateralCase.c,
        title: 'Case C (K ≤ 1)',
        rule: r'K \le 1 \quad (\text{Not unconditionally stable})',
        maxGainRule: r'\text{No MAG. Use MSG reference: } MSG = \frac{|S_{21}|}{|S_{12}|}',
        conjMatchRule: r'\text{Match not guaranteed. Prefer passive } |\Gamma|<1 \text{ if exists.}',
      );
    }

    // Case B: potentially unstable with K>1 but |Δ|>1
    if (K.isFinite && K > 1 && deltaAbs > 1) {
      return const CaseInfo(
        which: BilateralCase.b,
        title: 'Case B (Potentially Unstable)',
        rule: r'K > 1 \quad \text{and} \quad |\Delta| > 1',
        maxGainRule: r'\text{No MAG. Use MSG: } MSG = \frac{|S_{21}|}{|S_{12}|}',
        conjMatchRule: r'\text{Use plus sign (per note): } \Gamma_S = \Gamma_{Ms+},\; \Gamma_L = \Gamma_{ML+}',
      );
    }

    // Default fallback
    return const CaseInfo(
      which: BilateralCase.c,
      title: 'Case C (Fallback)',
      rule: r'\text{Unknown condition}',
      maxGainRule: r'\text{Use MSG reference}',
      conjMatchRule: r'\text{Prefer passive solutions}',
    );
  }

  Complex _sqrtRealAsComplex(double x) {
    if (x.isNaN) return const Complex(double.nan, double.nan);
    if (x.isInfinite) return Complex(x.isNegative ? 0 : double.infinity, 0);
    if (x >= 0) return Complex(sqrt(x), 0);
    return Complex(0, sqrt(-x)); // j*sqrt(|x|)
  }

  bool _isPassive(Complex? g) {
    if (g == null) return false;
    final m = g.modulus;
    return m.isFinite && m < 1;
  }

  Complex? _choosePassivePrefer(Complex? minus, Complex? plus) {
    final mOk = _isPassive(minus);
    final pOk = _isPassive(plus);
    if (mOk && !pOk) return minus;
    if (!mOk && pOk) return plus;
    if (mOk && pOk) {
      return (minus!.modulus <= plus!.modulus) ? minus : plus;
    }
    if (minus == null) return plus;
    if (plus == null) return minus;
    return (minus.modulus <= plus.modulus) ? minus : plus;
  }

  // Core calculation
  void _onCalculatePressed() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _hasCalculated = true;

      _stepPanels.clear();
      gainCirclesData.clear();
      _summaryTableData.clear();
      _expandedList = [];

      try {
        final S11 = ComplexParser.parseUniversal(_joinInput(s11C1, s11C2), _currentFormat);
        final S12 = ComplexParser.parseUniversal(_joinInput(s12C1, s12C2), _currentFormat);
        final S21 = ComplexParser.parseUniversal(_joinInput(s21C1, s21C2), _currentFormat);
        final S22 = ComplexParser.parseUniversal(_joinInput(s22C1, s22C2), _currentFormat);

        final S11abs = S11.modulus, S11abs2 = S11abs * S11abs;
        final S12abs = S12.modulus;
        final S21abs = S21.modulus, S21abs2 = S21abs * S21abs;
        final S22abs = S22.modulus, S22abs2 = S22abs * S22abs;

        if (S21abs < _eps) {
          _stepPanels.add(StepPanel(
            title: "Calculation Error",
            content: [
              const Text("Invalid Parameter: S21 ≈ 0 (No Gain).",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 4),
              const Text("Device cannot amplify."),
            ],
          ));
          _expandedList = [true];
          return;
        }

        // 1) Δ
        final delta = S11 * S22 - S12 * S21;
        final deltaAbs = delta.modulus, deltaAbs2 = deltaAbs * deltaAbs;

        // 2) K (allow S12=0)
        final denomKAbs = 2 * (S12abs * S21abs);
        final numK = 1 - S11abs2 - S22abs2 + deltaAbs2;
        final K = _safeDivideToInfinity(numK, denomKAbs);

        // 3) Kt (allow S12=0)
        final oneMinusDelta = Complex(1, 0) - delta;
        final oneMinusDeltaAbs2 = pow(oneMinusDelta.modulus, 2).toDouble();
        final numKt = 3 - 2 * S11abs2 - 2 * S22abs2 + deltaAbs2 - oneMinusDeltaAbs2;
        final denomKtAbs = 4 * (S12abs * S21abs);
        final Kt = _safeDivideToInfinity(numKt, denomKtAbs);

        // 4) mu and mu'
        final C2 = S22 - delta * S11.conjugate();
        final C1 = S11 - delta * S22.conjugate();
        final absS12S21 = (S12abs * S21abs);

        final denomMu = C2.modulus + absS12S21;
        final denomMuP = C1.modulus + absS12S21;

        final mu = (denomMu < _eps) ? double.nan : (1 - S11abs2) / denomMu;
        final muP = (denomMuP < _eps) ? double.nan : (1 - S22abs2) / denomMuP;

        // 5) Stability decisions
        final stableKDelta = (!K.isNaN) && (K.isInfinite ? (!K.isNegative) : (K > 1)) && (deltaAbs < 1);
        final stableKt = (!Kt.isNaN) && (Kt.isInfinite ? (!Kt.isNegative) : (Kt > 1));
        final stableMu = (!mu.isNaN) && (mu > 1);
        final stableMuP = (!muP.isNaN) && (muP > 1);

        _isUnconditionallyStable = stableKDelta;

        _caseInfo = _decideCase(K: K, deltaAbs: deltaAbs, stableKDelta: stableKDelta);
        _case = _caseInfo.which;

        _stepPanels.add(
          StepPanel(
            title: '0. Case Selection (A / B / C)',
            content: [
              _text('We classify the device into three teaching cases:', bold: true),

              // 使用 LaTeX 渲染分类标准
              _texScroll(r'\bullet\ \text{Case A: } K > 1 \text{ and } |\Delta| < 1 \to \text{Unconditionally stable}'),
              _texScroll(r'\bullet\ \text{Case B: } K > 1 \text{ and } |\Delta| > 1 \to \text{Potentially unstable}'),
              _texScroll(r'\bullet\ \text{Case C: } K \le 1 \to \text{Potentially unstable}'),

              const Divider(),

              _text('Chosen Case Analysis:', bold: true),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _caseInfo.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)
                    ),
                    const SizedBox(height: 8),

                    const Text("Condition:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                    // 渲染 rule
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Math.tex(_caseInfo.rule, textStyle: const TextStyle(fontSize: 15, color: Colors.black87)),
                    ),
                    const SizedBox(height: 8),

                    const Text("Max Gain Strategy:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                    // 渲染 maxGainRule
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Math.tex(_caseInfo.maxGainRule, textStyle: const TextStyle(fontSize: 15, color: Colors.black87)),
                    ),
                    const SizedBox(height: 8),

                    const Text("Conjugate Match Strategy:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                    // 渲染 conjMatchRule
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Math.tex(_caseInfo.conjMatchRule, textStyle: const TextStyle(fontSize: 15, color: Colors.black87)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        _stepPanels.add(
          StepPanel(
            title: '1. Stability (Δ, K, Kt, μ, μ′)',
            content: [
              _text('Core Definitions:', bold: true),
              _texScroll(r'\Delta = S_{11}S_{22}-S_{12}S_{21}'),
              _texScroll(r'K = \frac{1-|S_{11}|^2-|S_{22}|^2+|\Delta|^2}{2|S_{12}S_{21}|}'),
              _texScroll(
                  r'K_t = \frac{3-2|S_{11}|^2-2|S_{22}|^2+|\Delta|^2-|1-\Delta|^2}{4|S_{12}S_{21}|}'),
              _texScroll(
                  r'\mu = \frac{1-|S_{11}|^2}{|S_{22}-\Delta S_{11}^*|+|S_{12}S_{21}|}'),
              _texScroll(
                  r"\mu' = \frac{1-|S_{22}|^2}{|S_{11}-\Delta S_{22}^*|+|S_{12}S_{21}|}"),
              const Divider(),
              _text('Substitution (insert values; not simplified):', bold: true),
              _texScroll(
                r'S_{11}=' + ComplexFormatter.latex(S11, _currentFormat, precision: 3) +
                    r',\; S_{12}=' + ComplexFormatter.latex(S12, _currentFormat, precision: 3) +
                    r',\; S_{21}=' + ComplexFormatter.latex(S21, _currentFormat, precision: 3) +
                    r',\; S_{22}=' + ComplexFormatter.latex(S22, _currentFormat, precision: 3),
              ),
              _texScroll(
                r'\Delta = S_{11}S_{22}-S_{12}S_{21}'
                r' = (' + ComplexFormatter.latex(S11, _currentFormat, precision: 3) + r')(' +
                    ComplexFormatter.latex(S22, _currentFormat, precision: 3) + r') - (' +
                    ComplexFormatter.latex(S12, _currentFormat, precision: 3) + r')(' +
                    ComplexFormatter.latex(S21, _currentFormat, precision: 3) + r')',
              ),
              _texScroll(
                r'K = \frac{1-|S_{11}|^2-|S_{22}|^2+|\Delta|^2}{2|S_{12}S_{21}|}'
                r' = \frac{1-' + _texNumSafe(S11abs2) + r'-' + _texNumSafe(S22abs2) + r'+' + _texNumSafe(deltaAbs2) + r'}{2\cdot ' +
                    _texNumSafe(S12abs) + r'\cdot ' + _texNumSafe(S21abs) + r'}',
              ),
              _texScroll(
                r'K_t = \frac{3-2|S_{11}|^2-2|S_{22}|^2+|\Delta|^2-|1-\Delta|^2}{4|S_{12}S_{21}|}'
                r' = \frac{3-2\cdot' + _texNumSafe(S11abs2) + r'-2\cdot' + _texNumSafe(S22abs2) + r'+' + _texNumSafe(deltaAbs2) + r'-' + _texNumSafe(oneMinusDeltaAbs2) + r'}{4\cdot ' +
                    _texNumSafe(S12abs) + r'\cdot ' + _texNumSafe(S21abs) + r'}',
              ),
              _texScroll(
                r'\mu = \frac{1-|S_{11}|^2}{|S_{22}-\Delta S_{11}^*|+|S_{12}S_{21}|}'
                r' = \frac{1-' + _texNumSafe(S11abs2) + r'}{|'
                    + ComplexFormatter.latex(S22, _currentFormat, precision: 3) + r'-('
                    + ComplexFormatter.latex(delta, _currentFormat, precision: 3) + r')('
                    + ComplexFormatter.latex(S11.conjugate(), _currentFormat, precision: 3) + r')| + '
                    + _texNumSafe(absS12S21) + r'}',
              ),
              _texScroll(
                r"\mu' = \frac{1-|S_{22}|^2}{|S_{11}-\Delta S_{22}^*|+|S_{12}S_{21}|}"
                r" = \frac{1-" + _texNumSafe(S22abs2) + r"}{|"
                    + ComplexFormatter.latex(S11, _currentFormat, precision: 3) + r"-("
                    + ComplexFormatter.latex(delta, _currentFormat, precision: 3) + r")("
                    + ComplexFormatter.latex(S22.conjugate(), _currentFormat, precision: 3) + r")| + "
                    + _texNumSafe(absS12S21) + r"}",
              ),
              const Divider(),
              _text('Substitution & Results:', bold: true),
              _texScroll(r'|\Delta| = ' + _texNumSafe(deltaAbs)),
              _texScroll(r'K = ' + _texNumSafe(K)),
              if (S12abs < _eps) _text(_infExplain('K', numK, denomKAbs), bold: true),
              _texScroll(r'K_t = ' + _texNumSafe(Kt)),
              if (S12abs < _eps) _text(_infExplain('Kt', numKt, denomKtAbs), bold: true),
              _texScroll(r'\mu = ' + _texNumSafe(mu)),
              _texScroll(r"\mu' = " + _texNumSafe(muP)),
              const Divider(),
              _text('Stability Criteria:', bold: true),
              _text('• Unconditionally stable (classic):  K > 1  AND  |Δ| < 1'),
              _text('• Single-parameter criterion:          Kt > 1'),
              _text("• Mu criteria:                         μ > 1  AND  μ' > 1"),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isUnconditionallyStable ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isUnconditionallyStable ? Colors.green.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isUnconditionallyStable ? "✅ Unconditionally Stable (by K & |Δ|)" : "⚠️ Not Unconditionally Stable (by K & |Δ|)",
                      style: TextStyle(
                        color: _isUnconditionallyStable ? Colors.green[800] : Colors.deepOrange[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Chosen teaching case: ${_caseInfo.title}",
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Kt>1: ${stableKt ? "Yes" : "No"}   |   μ>1: ${stableMu ? "Yes" : "No"}   |   μ'>1: ${stableMuP ? "Yes" : "No"}",
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        double? magLin, magDb;
        double? msgLin, msgDb;

        if (S12abs < _eps) {
          msgLin = double.infinity;
          msgDb = double.infinity;
        } else {
          msgLin = S21abs / S12abs;
          msgDb = (msgLin <= 1e-12) ? -999.0 : 10 * log(msgLin) / ln10;
        }

        if (_case == BilateralCase.a) {
          if (S12abs < _eps) {
            final den = (1 - S11abs2) * (1 - S22abs2);
            if (den.abs() < _eps) {
              magLin = double.infinity;
              magDb = double.infinity;
            } else {
              magLin = S21abs2 / den;
              magDb = (magLin! <= 1e-12) ? -999.0 : 10 * log(magLin!) / ln10;
            }

            _stepPanels.add(
              StepPanel(
                title: '2. Maximum Gain (Case A → MAG, S12=0 → use GTUmax)',
                content: [
                  _text('Case A: K>1 and |Δ|<1 → MAG can be claimed.', bold: true),
                  _text('Since S12 ≈ 0, use unilateral GTUmax.', bold: true),
                  const Divider(),
                  _text('Substitution (insert values; not simplified):', bold: true),
                  _texScroll(
                    r'MAG = \frac{|S_{21}|^2}{(1-|S_{11}|^2)(1-|S_{22}|^2)}'
                    r' = \frac{' + _texNumSafe(S21abs2) + r'}{(1-' + _texNumSafe(S11abs2) + r')(1-' + _texNumSafe(S22abs2) + r')}',
                  ),
                  const Divider(),
                  _text('Result:', bold: true),
                  _texScroll(r'MAG = ' + _texNumSafe(magLin!) + r'\quad (' + _texNumSafe(magDb!) + r'\,\text{dB})'),
                  const Divider(),
                  _text('Also (reference): MSG = |S21|/|S12|', bold: true),
                  _texScroll(r'MSG = ' + _texNumSafe(msgLin!) + r'\quad (' + _texNumSafe(msgDb!) + r'\,\text{dB})'),
                ],
              ),
            );
          } else {
            final term = (K - sqrt(K * K - 1));
            magLin = msgLin! * term;
            magDb = (magLin! <= 1e-12) ? -999.0 : 10 * log(magLin!) / ln10;

            _stepPanels.add(
              StepPanel(
                title: '2. Maximum Gain (Case A → MAG)',
                content: [
                  _text('Case A: K>1 and |Δ|<1 → claim MAG.', bold: true),
                  _text('Formulas:', bold: true),
                  _texScroll(r'MSG = \frac{|S_{21}|}{|S_{12}|}'),
                  _texScroll(r'MAG = MSG\cdot\left(K - \sqrt{K^2 - 1}\right)'),
                  const Divider(),
                  _text('Substitution (insert values; not simplified):', bold: true),
                  _texScroll(
                    r'MSG = \frac{|S_{21}|}{|S_{12}|} = \frac{' + _texNumSafe(S21abs) + r'}{' + _texNumSafe(S12abs) + r'}',
                  ),
                  _texScroll(
                    r'MAG = MSG\cdot\left(K-\sqrt{K^2-1}\right)'
                    r' = (' + _texNumSafe(msgLin!) + r')\cdot\left(' + _texNumSafe(K) + r'-\sqrt{(' + _texNumSafe(K) + r')^2-1}\right)',
                  ),
                  const Divider(),
                  _text('Results:', bold: true),
                  _texScroll(r'MSG = ' + _texNumSafe(msgLin!) + r'\quad (' + _texNumSafe(msgDb!) + r'\,\text{dB})'),
                  _texScroll(r'MAG = ' + _texNumSafe(magLin!) + r'\quad (' + _texNumSafe(magDb!) + r'\,\text{dB})'),
                  const Divider(),
                  _text('For Case A under simultaneous conjugate match:', bold: true),
                  _texScroll(r'G_{p,\max}=G_{t,\max}=G_{a,\max}=MAG'),
                ],
              ),
            );
          }
        } else if (_case == BilateralCase.b) {
          _stepPanels.add(
            StepPanel(
              title: '2. Maximum Gain (Case B → use MSG; do NOT claim MAG)',
              content: [
                _text('Case B: K>1 but |Δ|>1 → potentially unstable.', bold: true),
                _text('Per note: choose plus sign for ΓMs/ΓML, but gain is NOT maximum yet.', bold: true),
                const Divider(),
                _text('Formula:', bold: true),
                _texScroll(r'MSG = \frac{|S_{21}|}{|S_{12}|}'),
                _text('Substitution (insert values; not simplified):', bold: true),
                _texScroll(r'MSG = \frac{' + _texNumSafe(S21abs) + r'}{' + _texNumSafe(S12abs) + r'}'),
                const Divider(),
                _text('Result:', bold: true),
                _texScroll(r'MSG = ' + _texNumSafe(msgLin!) + r'\quad (' + _texNumSafe(msgDb!) + r'\,\text{dB})'),
              ],
            ),
          );
        } else {
          _stepPanels.add(
            StepPanel(
              title: '2. Maximum Gain (Case C → K≤1, use MSG reference)',
              content: [
                _text('Case C: K ≤ 1 → simultaneous conjugate match is not guaranteed.', bold: true),
                _text('Still compute MSG as a reference (teaching).', bold: true),
                const Divider(),
                _text('Formula:', bold: true),
                _texScroll(r'MSG = \frac{|S_{21}|}{|S_{12}|}'),
                _text('Substitution (insert values; not simplified):', bold: true),
                _texScroll(r'MSG = \frac{' + _texNumSafe(S21abs) + r'}{' + _texNumSafe(S12abs) + r'}'),
                const Divider(),
                _text('Result:', bold: true),
                _texScroll(r'MSG = ' + _texNumSafe(msgLin!) + r'\quad (' + _texNumSafe(msgDb!) + r'\,\text{dB})'),
              ],
            ),
          );
        }

        final dbList = gainDbListC.text
            .split(',')
            .map((e) => double.tryParse(e.trim()))
            .whereType<double>()
            .toList();

        final List<Widget> circleWidgets = [];

        circleWidgets.add(
          Card(
            elevation: 0,
            color: Colors.grey[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ExpansionTile(
              title: const Text(
                "General Formulas & Constants",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              subtitle: const Text("Click to view basic formulas", style: TextStyle(fontSize: 12, color: Colors.grey)),
              childrenPadding: const EdgeInsets.all(16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text('General Formulas:', bold: true),
                _texScroll(r'g_p = \frac{10^{G_{dB}/10}}{|S_{21}|^2}'),
                _texScroll(r'C_p = \frac{g_p C_2^*}{1 + g_p(|S_{22}|^2 - |\Delta|^2)}'),
                _texScroll(
                  r'r_p = \frac{\sqrt{1 - 2K|S_{12}S_{21}|g_p + |S_{12}S_{21}|^2 g_p^2}}{|1 + g_p(|S_{22}|^2 - |\Delta|^2)|}',
                ),
                const SizedBox(height: 6),
                _text('Robust form (avoids K=±∞):', bold: true),
                _texScroll(
                  r'1 - 2K|S_{12}S_{21}|g_p + |S_{12}S_{21}|^2 g_p^2'
                  r' = 1 - (1-|S_{11}|^2-|S_{22}|^2+|\Delta|^2)\,g_p + |S_{12}S_{21}|^2 g_p^2',
                ),
                const Divider(),
                _text('Intermediate Constant:', bold: true),
                _texScroll(r'C_2 = S_{22} - \Delta S_{11}^* = ' + ComplexFormatter.latexHybrid(C2, precision: 3)),
              ],
            ),
          ),
        );

        circleWidgets.add(const SizedBox(height: 12));

        final absS12S21_sq = absS12S21 * absS12S21;

        for (int i = 0; i < dbList.length; i++) {
          final currentGpDB = dbList[i];

          if (_case == BilateralCase.a && magDb != null && magDb!.isFinite && currentGpDB > magDb!) {
            final magDbStr = ComplexFormatter.smartFormat(magDb!, precision: 3);
            final targetStr = ComplexFormatter.smartFormat(currentGpDB, precision: 3);

            circleWidgets.add(
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  '⚠️ Target gain ($targetStr dB) > MAG ($magDbStr dB). Circle not physically realizable (Active Load).',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            );
            continue;
          }

          final currentGpLin = pow(10, currentGpDB / 10).toDouble();
          final gp = currentGpLin / S21abs2;

          final denominatorCp = 1 + gp * (S22abs2 - deltaAbs2);
          if (denominatorCp.abs() < 1e-12) continue;

          final Cp = C2.conjugate() * Complex(gp, 0) / Complex(denominatorCp, 0);

          final numeratorRp = 1 - (numK) * gp + (absS12S21_sq) * gp * gp;

          if (numeratorRp < 0) {
            circleWidgets.add(
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  '⚠️ Gain $currentGpDB dB not realizable (Discriminant < 0).',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            );
            continue;
          }

          final rp = sqrt(numeratorRp) / denominatorCp.abs();

          gainCirclesData.add(
            GainCircleData(
              center: Cp,
              radius: rp,
              label: '${ComplexFormatter.smartFormat(currentGpDB)}dB',
              color: _case == BilateralCase.a ? Colors.green : Colors.orange,
            ),
          );

          _summaryTableData.add([
            ComplexFormatter.smartFormat(currentGpDB),
            ComplexFormatter.smartFormat(gp, precision: 4),
            ComplexFormatter.universal(Cp, _currentFormat, precision: 3),
            ComplexFormatter.smartFormat(rp, precision: 4),
          ]);

          final List<Widget> circleSteps = [];
          circleSteps.add(_text('1. Normalized Gain (gp):', bold: true));
          circleSteps.add(_texScroll(
              r'g_p = \frac{10^{(' + _texNumSafe(currentGpDB) + r'/10)}}{|' + _texNumSafe(S21abs) + r'|^2} = ' + _texNumSafe(gp)));
          circleSteps.add(const Divider());

          circleSteps.add(_text('2. Center (Cp):', bold: true));
          circleSteps.add(_texScroll(
            r'C_p = \frac{' +
                _texNumSafe(gp) +
                r' \cdot (' +
                ComplexFormatter.latex(C2.conjugate(), _currentFormat, precision: 2) +
                r')}{' +
                _texNumSafe(denominatorCp) +
                r'}',
          ));
          circleSteps.add(_texScroll(r'= ' + ComplexFormatter.latexHybrid(Cp, precision: 3)));
          circleSteps.add(const Divider());

          circleSteps.add(_text('3. Radius (rp):', bold: true));
          circleSteps.add(_texScroll(
              r'r_p = \frac{\sqrt{1 - (1-|S_{11}|^2-|S_{22}|^2+|\Delta|^2)\,g_p + |S_{12}S_{21}|^2 g_p^2}}{|1 + g_p(|S_{22}|^2 - |\Delta|^2)|}'
              r' = ' + _texNumSafe(rp)));

          circleWidgets.add(
            Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ExpansionTile(
                title: Text(
                  "Circle ${i + 1}: Gain = ${ComplexFormatter.smartFormat(currentGpDB)} dB",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                initiallyExpanded: false,
                childrenPadding: const EdgeInsets.all(16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: circleSteps,
              ),
            ),
          );
        }

        _stepPanels.add(
          StepPanel(
            title: '3. Operating Power Gain Circles',
            content: circleWidgets,
          ),
        );

        final B1 = 1 + S11abs2 - S22abs2 - deltaAbs2;
        final B2 = 1 + S22abs2 - S11abs2 - deltaAbs2;

        final C1abs2 = C1.modulus * C1.modulus;
        final C2abs2 = C2.modulus * C2.modulus;

        final discrim1 = B1 * B1 - 4 * C1abs2;
        final discrim2 = B2 * B2 - 4 * C2abs2;

        final sqrtDisc1 = _sqrtRealAsComplex(discrim1);
        final sqrtDisc2 = _sqrtRealAsComplex(discrim2);

        final twoC1 = C1 * const Complex(2, 0);
        final twoC2 = C2 * const Complex(2, 0);

        Complex? GmsMinus, GmsPlus, GmlMinus, GmlPlus;

        if (twoC1.modulus > _eps) {
          GmsMinus = (Complex(B1, 0) - sqrtDisc1) / twoC1;
          GmsPlus = (Complex(B1, 0) + sqrtDisc1) / twoC1;
        }
        if (twoC2.modulus > _eps) {
          GmlMinus = (Complex(B2, 0) - sqrtDisc2) / twoC2;
          GmlPlus = (Complex(B2, 0) + sqrtDisc2) / twoC2;
        }

        Complex? chosenGs;
        Complex? chosenGl;

        if (_case == BilateralCase.a) {
          chosenGs = GmsMinus;
          chosenGl = GmlMinus;
        } else if (_case == BilateralCase.b) {
          chosenGs = GmsPlus;
          chosenGl = GmlPlus;
        } else {
          chosenGs = _choosePassivePrefer(GmsMinus, GmsPlus);
          chosenGl = _choosePassivePrefer(GmlMinus, GmlPlus);
        }

        _stepPanels.add(
          StepPanel(
            title: '4. Simultaneous Conjugate Match (ΓMs, ΓML) — Case-based',
            content: [
              _text('Formulas:', bold: true),
              _texScroll(r'\Gamma_{Ms\pm} = \frac{B_1 \pm \sqrt{B_1^2 - 4|C_1|^2}}{2C_1}'),
              _texScroll(r'\Gamma_{ML\pm} = \frac{B_2 \pm \sqrt{B_2^2 - 4|C_2|^2}}{2C_2}'),
              const Divider(),
              _text('Where:', bold: true),
              _texScroll(r'B_1 = 1 + |S_{11}|^2 - |S_{22}|^2 - |\Delta|^2'),
              _texScroll(r'B_2 = 1 + |S_{22}|^2 - |S_{11}|^2 - |\Delta|^2'),
              _texScroll(r'C_1 = S_{11} - \Delta S_{22}^*'),
              _texScroll(r'C_2 = S_{22} - \Delta S_{11}^*'),
              const Divider(),
              _text('Substitution (insert values; not simplified):', bold: true),
              _texScroll(
                r'B_1 = 1 + |S_{11}|^2 - |S_{22}|^2 - |\Delta|^2'
                r' = 1 + ' + _texNumSafe(S11abs2) + r' - ' + _texNumSafe(S22abs2) + r' - ' + _texNumSafe(deltaAbs2),
              ),
              _texScroll(
                r'B_2 = 1 + |S_{22}|^2 - |S_{11}|^2 - |\Delta|^2'
                r' = 1 + ' + _texNumSafe(S22abs2) + r' - ' + _texNumSafe(S11abs2) + r' - ' + _texNumSafe(deltaAbs2),
              ),
              _texScroll(
                r'C_1 = S_{11} - \Delta S_{22}^*'
                r' = (' + ComplexFormatter.latex(S11, _currentFormat, precision: 3) + r') - ('
                    + ComplexFormatter.latex(delta, _currentFormat, precision: 3) + r')('
                    + ComplexFormatter.latex(S22.conjugate(), _currentFormat, precision: 3) + r')',
              ),
              _texScroll(
                r'C_2 = S_{22} - \Delta S_{11}^*'
                r' = (' + ComplexFormatter.latex(S22, _currentFormat, precision: 3) + r') - ('
                    + ComplexFormatter.latex(delta, _currentFormat, precision: 3) + r')('
                    + ComplexFormatter.latex(S11.conjugate(), _currentFormat, precision: 3) + r')',
              ),
              _texScroll(
                r'B_1^2 - 4|C_1|^2 = (' + _texNumSafe(B1) + r')^2 - 4\cdot(' + _texNumSafe(C1.modulus) + r')^2 = ' + _texNumSafe(discrim1),
              ),
              _texScroll(
                r'B_2^2 - 4|C_2|^2 = (' + _texNumSafe(B2) + r')^2 - 4\cdot(' + _texNumSafe(C2.modulus) + r')^2 = ' + _texNumSafe(discrim2),
              ),
              const Divider(),
              _text('Computed Solutions (show both ±):', bold: true),
              if (GmsMinus != null) _texScroll(r'\Gamma_{Ms-} = ' + ComplexFormatter.latex(GmsMinus, _currentFormat, precision: 3)),
              if (GmsPlus != null) _texScroll(r'\Gamma_{Ms+} = ' + ComplexFormatter.latex(GmsPlus, _currentFormat, precision: 3)),
              if (GmlMinus != null) _texScroll(r'\Gamma_{ML-} = ' + ComplexFormatter.latex(GmlMinus, _currentFormat, precision: 3)),
              if (GmlPlus != null) _texScroll(r'\Gamma_{ML+} = ' + ComplexFormatter.latex(GmlPlus, _currentFormat, precision: 3)),
              const Divider(),

              _text('Chosen (ΓS, ΓL) by case:', bold: true),

              // 1. Selection Rule in LaTeX
              _texScroll(r'\textbf{Selection Rule:}\quad ' + _caseInfo.conjMatchRule),

              // 2. Gamma S in LaTeX
              if (chosenGs != null)
                _texScroll(r'\Gamma_S = ' + ComplexFormatter.latex(chosenGs, _currentFormat, precision: 3))
              else
                _texScroll(r'\Gamma_S: \text{undefined } (|2C_1| \approx 0)'),

              // 3. Gamma L in LaTeX
              if (chosenGl != null)
                _texScroll(r'\Gamma_L = ' + ComplexFormatter.latex(chosenGl, _currentFormat, precision: 3))
              else
                _texScroll(r'\Gamma_L: \text{undefined } (|2C_2| \approx 0)'),

              const Divider(),

              // 4. Notes in LaTeX (FIXED: Using list spread to avoid '\\' newline crash)
              if (_case == BilateralCase.c) ...[
                _texScroll(r'\textbf{Note (Case C):}\ K \le 1 \implies \text{Match not guaranteed.}'),
                _texScroll(r'\text{Showing } \Gamma_{Ms\pm}/\Gamma_{ML\pm} \text{ for teaching reference.}'),
                _texScroll(r'\text{Prefer passive solutions } (|\Gamma|<1) \text{ if available.}'),
              ],

              if (_case == BilateralCase.b) ...[
                _texScroll(r'\textbf{Note (Case B):}\ K > 1 \text{ and } |\Delta| > 1 \implies \text{Use (+) sign.}'),
                _texScroll(r'\text{However, do NOT claim } G_{max} \text{ (potential instability).}'),
              ],

              if (_case == BilateralCase.a) ...[
                _texScroll(r'\textbf{Note (Case A):}\ \text{Unconditionally stable} \implies \text{Use (-) sign.}'),
                _texScroll(r'\text{Must use } \Gamma_S = \Gamma_{Ms-},\; \Gamma_L = \Gamma_{ML-}.'),
              ],
            ],
          ),
        );

        _expandedList = List.generate(_stepPanels.length, (_) => false);
      } catch (e) {
        debugPrint("Error: $e");
        _stepPanels.add(
          StepPanel(
            title: "Internal Error",
            content: [Text("An error occurred: $e", style: const TextStyle(color: Colors.red))],
          ),
        );
        _expandedList = [true];
      }
    });
  }

  // Summary table
  Widget _buildSummaryTable() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Circles Summary",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                columns: const [
                  DataColumn(label: Text('Gain (dB)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('gp', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Center (Cp)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Radius (rp)', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _summaryTableData.map((row) {
                  return DataRow(
                    cells: [
                      DataCell(Text(row[0], style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row[1])),
                      DataCell(Text(row[2])),
                      DataCell(Text(row[3])),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: 'Bilateral Gain Circles',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.compare_arrows, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Bilateral Mode", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(color: Colors.green[800], fontSize: 12),
                              children: const [
                                TextSpan(text: "Assumes bilateral model, but robustly handles "),
                                TextSpan(text: "S12 = 0", style: TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: " without skipping."),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              _buildExampleBar(),
              const SizedBox(height: 14),

              // Format buttons
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

              // Inputs with smooth Keyboard Action flow (Next -> Next -> ... -> Done)
              ComplexInputRow(
                format: _currentFormat,
                ctrl1: s11C1,
                ctrl2: s11C2,
                paramName: 'S11',
                validator: commonValidator,
                onAnyChanged: _onInputChanged,
                onSubmit: _onCalculatePressed,
                action1: TextInputAction.next,
                action2: TextInputAction.next,
              ),
              ComplexInputRow(
                format: _currentFormat,
                ctrl1: s12C1,
                ctrl2: s12C2,
                paramName: 'S12',
                validator: commonValidator,
                onAnyChanged: _onInputChanged,
                onSubmit: _onCalculatePressed,
                action1: TextInputAction.next,
                action2: TextInputAction.next,
              ),
              ComplexInputRow(
                format: _currentFormat,
                ctrl1: s21C1,
                ctrl2: s21C2,
                paramName: 'S21',
                validator: commonValidator,
                onAnyChanged: _onInputChanged,
                onSubmit: _onCalculatePressed,
                action1: TextInputAction.next,
                action2: TextInputAction.next,
              ),
              ComplexInputRow(
                format: _currentFormat,
                ctrl1: s22C1,
                ctrl2: s22C2,
                paramName: 'S22',
                validator: commonValidator,
                onAnyChanged: _onInputChanged,
                onSubmit: _onCalculatePressed,
                action1: TextInputAction.next,
                action2: TextInputAction.next,
              ),

              const SizedBox(height: 12),
              _buildScalarInput(
                z0C,
                'Z0 (Ohm)',
                validator: commonValidator,
                onAnyChanged: _onInputChanged,
                onSubmit: _onCalculatePressed,
                action: TextInputAction.next,
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: gainDbListC,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                // Last field: Action is Done
                textInputAction: TextInputAction.done,
                onChanged: (_) => _onInputChanged(),
                onFieldSubmitted: (_) => _onCalculatePressed(),
                decoration: const InputDecoration(
                  labelText: 'Target Gains (dB, comma separated)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  isDense: true,
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _onCalculatePressed,
                  icon: const Icon(Icons.calculate),
                  label: const Text('Calculate Gain Circles', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              if (_hasCalculated) ...[
                if (gainCirclesData.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, spreadRadius: 1)],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Smith Chart Visualization",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 350,
                          child: SmithGainCirclePainter(
                            gainCircles: gainCirclesData,
                            canvasSize: 350,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_summaryTableData.isNotEmpty) _buildSummaryTable(),

                const SizedBox(height: 20),
                if (_stepPanels.isNotEmpty && _stepPanels[0].title != "Calculation Error")
                  const Text("Detailed Derivation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),

                ExpansionPanelList(
                  expansionCallback: (panelIndex, isExpanded) {
                    setState(() {
                      if (panelIndex < _expandedList.length) {
                        _expandedList[panelIndex] = !_expandedList[panelIndex];
                      }
                    });
                  },
                  children: _stepPanels.asMap().entries.map((entry) {
                    final isErrorPanel = entry.value.title == "Calculation Error";
                    final headerColor = isErrorPanel
                        ? Colors.red
                        : (entry.key < _expandedList.length && _expandedList[entry.key] ? Colors.deepPurple : Colors.black87);

                    return ExpansionPanel(
                      headerBuilder: (context, isExpanded) => ListTile(
                        title: _panelHeaderTitle(entry.value.title, color: headerColor),
                      ),
                      body: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: entry.value.content,
                        ),
                      ),
                      isExpanded: entry.key < _expandedList.length ? _expandedList[entry.key] : false,
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