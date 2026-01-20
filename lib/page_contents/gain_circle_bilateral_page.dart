import 'dart:math';
import 'package:flutter/material.dart';
import 'package:equations/equations.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../functional_components/menu_functions.dart';
import '../input_and_output_functions/utils.dart';
import '../functional_components/fixed_input.dart';
import '../smith_chart_db_module/smith_gain_circle_painter.dart';

// ==========================================
// Simple data structure: Step panels
// ==========================================
class StepPanel {
  final String title;
  final List<Widget> content;
  StepPanel({required this.title, required this.content});
}

// ==========================================
// Example data structure
// ==========================================
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

class GainCircleBilateralPage extends StatefulWidget {
  const GainCircleBilateralPage({super.key});

  @override
  State<GainCircleBilateralPage> createState() => _GainCircleBilateralPageState();
}

class _GainCircleBilateralPageState extends State<GainCircleBilateralPage> {
  final _formKey = GlobalKey<FormState>();

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

  // Examples
  late final List<GainCircleExample> _examples;
  int _exampleIndex = 0;

  @override
  void initState() {
    super.initState();

    // Put your provided examples near the front:
    _examples = const [
      // From your image: Example 4-4
      GainCircleExample(
        name: 'Example 4-4 (1.8 GHz, Bilateral)',
        s11Mag: 0.26, s11AngDeg: -55,
        s12Mag: 0.08, s12AngDeg: 80,
        s21Mag: 2.14, s21AngDeg: 65,
        s22Mag: 0.82, s22AngDeg: -30,
        z0: 50,
        gainDbList: '6, 8, 10',
      ),
      // From your image: Example 4-5
      GainCircleExample(
        name: 'Example 4-5 (8 GHz, Bilateral)',
        s11Mag: 0.5, s11AngDeg: -180,
        s12Mag: 0.08, s12AngDeg: 30,
        s21Mag: 2.5, s21AngDeg: 70,
        s22Mag: 0.8, s22AngDeg: -100,
        z0: 50,
        gainDbList: '10',
      ),
      // Original placeholder (your previous default)
      GainCircleExample(
        name: 'Example (Pozar 11.4 style)',
        s11Mag: 0.6, s11AngDeg: -60,
        s12Mag: 0.05, s12AngDeg: 26,
        s21Mag: 1.9, s21AngDeg: 81,
        s22Mag: 0.5, s22AngDeg: -60,
        z0: 50,
        gainDbList: '6, 8, 10',
      ),
      // Extra: smaller reverse isolation but still bilateral
      GainCircleExample(
        name: 'Extra Example (Low feedback)',
        s11Mag: 0.35, s11AngDeg: -20,
        s12Mag: 0.02, s12AngDeg: 110,
        s21Mag: 3.2, s21AngDeg: 40,
        s22Mag: 0.55, s22AngDeg: -75,
        z0: 50,
        gainDbList: '5, 8, 11',
      ),
      // Extra: tends to push K down (often potentially unstable)
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

  // ==========================================
  // Helpers: Join & parse complex input
  // ==========================================
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

  // ==========================================
  // Example cycle (NO SnackBar)
  // ==========================================
  void _applyExample(GainCircleExample ex, {required bool autoCalculate}) {
    setState(() {
      _setComplexControllers(s11C1, s11C2, ex.S11);
      _setComplexControllers(s12C1, s12C2, ex.S12);
      _setComplexControllers(s21C1, s21C2, ex.S21);
      _setComplexControllers(s22C1, s22C2, ex.S22);

      z0C.text = ComplexFormatter.smartFormat(ex.z0, useScientific: false, precision: 6);
      gainDbListC.text = ex.gainDbList;

      // Clear old results (optional)
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

  // ==========================================
  // Format switching
  // ==========================================
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

  // ==========================================
  // UI helpers
  // ==========================================
  String _texNum(double val) => ComplexFormatter.smartFormat(val, useLatex: true);

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

  Widget _buildScalarInput(TextEditingController controller, String label, {String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        isDense: true,
      ),
    );
  }

  // Match your Unilateral "Next Example" pill style
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

  // ===============================================
  // Core calculation
  // ===============================================
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

        // --- Guard rails ---
        if (S12abs < 1e-9) {
          _stepPanels.add(StepPanel(
            title: "Calculation Error",
            content: [
              const Text("Invalid Parameter: S12 ≈ 0 (No Feedback).",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 4),
              const Text("Please use the 'Unilateral Gain Circles' module."),
            ],
          ));
          _expandedList = [true];
          return;
        }
        if (S21abs < 1e-9) {
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

        // 1) Stability: K, Δ
        final delta = S11 * S22 - S12 * S21;
        final deltaAbs = delta.modulus, deltaAbs2 = deltaAbs * deltaAbs;

        final K = (1 + deltaAbs2 - S11abs2 - S22abs2) / (2 * S12abs * S21abs);
        _isUnconditionallyStable = (K > 1 && deltaAbs < 1);

        _stepPanels.add(
          StepPanel(
            title: '1. Stability Check (K, Δ)',
            content: [
              _text('Formula:', bold: true),
              _texScroll(r'K = \frac{1 - |S_{11}|^2 - |S_{22}|^2 + |\Delta|^2}{2|S_{12}||S_{21}|}'),
              _text('Substitution:', bold: true),
              _texScroll(
                r'K = \frac{1 - ' +
                    _texNum(S11abs2) +
                    r' - ' +
                    _texNum(S22abs2) +
                    r' + ' +
                    _texNum(deltaAbs2) +
                    r'}{2 \cdot ' +
                    _texNum(S12abs) +
                    r' \cdot ' +
                    _texNum(S21abs) +
                    r'}',
              ),
              _text('Result:', bold: true),
              _texScroll(r'K = ' + _texNum(K)),
              _texScroll(r'|\Delta| = ' + _texNum(deltaAbs)),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                color: _isUnconditionallyStable ? Colors.green[50] : Colors.orange[50],
                child: Text(
                  _isUnconditionallyStable ? "✅ Unconditionally Stable" : "⚠️ Potentially Unstable",
                  style: TextStyle(
                    color: _isUnconditionallyStable ? Colors.green[800] : Colors.deepOrange[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

        // 2) MAG / MSG
        double? GpMaxLin, GpMaxDb;
        final MSG = S21abs / S12abs;
        final MSGdB = (MSG <= 1e-12) ? -999.0 : 10 * log(MSG) / ln10;

        if (_isUnconditionallyStable) {
          final term = (K - sqrt(K * K - 1));
          GpMaxLin = MSG * term;
          GpMaxDb = (GpMaxLin <= 1e-12) ? -999.0 : 10 * log(GpMaxLin) / ln10;

          _stepPanels.add(
            StepPanel(
              title: '2. Maximum Operating Power Gain (MAG)',
              content: [
                _text('Since K > 1, MAG exists.'),
                _text('Formula:', bold: true),
                _texScroll(r'MAG = \frac{|S_{21}|}{|S_{12}|} (K - \sqrt{K^2 - 1})'),
                _text('Result:', bold: true),
                _texScroll(r'MAG = ' + _texNum(GpMaxLin) + r' \quad (' + _texNum(GpMaxDb!) + r' \text{ dB})'),
              ],
            ),
          );
        } else {
          _stepPanels.add(
            StepPanel(
              title: '2. Maximum Stable Gain (MSG)',
              content: [
                _text('Device is potentially unstable. Using MSG.'),
                _text('Formula:', bold: true),
                _texScroll(r'MSG = \frac{|S_{21}|}{|S_{12}|}'),
                _text('Result:', bold: true),
                _texScroll(r'MSG = ' + _texNum(MSG) + r' \quad (' + _texNum(MSGdB) + r' \text{ dB})'),
              ],
            ),
          );
        }

        // 3) Gain circles
        final dbList = gainDbListC.text
            .split(',')
            .map((e) => double.tryParse(e.trim()))
            .whereType<double>()
            .toList();

        final C2 = S22 - delta * S11.conjugate();

        final List<Widget> circleWidgets = [];

        // Drawer A: General formulas
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
                _texScroll(r'r_p = \frac{\sqrt{1 - 2K|S_{12}S_{21}|g_p + |S_{12}S_{21}|^2 g_p^2}}{|1 + g_p(|S_{22}|^2 - |\Delta|^2)|}'),
                const Divider(),
                _text('Intermediate Constant:', bold: true),
                _texScroll(r'C_2 = S_{22} - \Delta S_{11}^* = ' + ComplexFormatter.latexHybrid(C2, precision: 3)),
              ],
            ),
          ),
        );

        circleWidgets.add(const SizedBox(height: 12));

        final S12S21abs = S12abs * S21abs;

        for (int i = 0; i < dbList.length; i++) {
          final currentGpDB = dbList[i];

          if (_isUnconditionallyStable && GpMaxDb != null && currentGpDB > GpMaxDb) {
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
                  '⚠️ Target gain ($currentGpDB dB) > MAG. Circle not physically realizable (Active Load).',
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

          final numeratorRp = 1 - 2 * K * S12S21abs * gp + pow(S12S21abs, 2) * gp * gp;

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

          // Painter data
          gainCirclesData.add(
            GainCircleData(
              center: Cp,
              radius: rp,
              label: '${ComplexFormatter.smartFormat(currentGpDB)}dB',
              color: _isUnconditionallyStable ? Colors.green : Colors.orange,
            ),
          );

          // Summary table
          _summaryTableData.add([
            ComplexFormatter.smartFormat(currentGpDB),
            ComplexFormatter.smartFormat(gp, precision: 4),
            ComplexFormatter.universal(Cp, _currentFormat, precision: 3),
            ComplexFormatter.smartFormat(rp, precision: 4),
          ]);

          // Drawer per circle
          final List<Widget> circleSteps = [];
          circleSteps.add(_text('1. Normalized Gain (gp):', bold: true));
          circleSteps.add(_texScroll(r'g_p = \frac{10^{(' + _texNum(currentGpDB) + r'/10)}}{|' + _texNum(S21abs) + r'|^2} = ' + _texNum(gp)));
          circleSteps.add(const Divider());

          circleSteps.add(_text('2. Center (Cp):', bold: true));
          circleSteps.add(
            _texScroll(
              r'C_p = \frac{' +
                  _texNum(gp) +
                  r' \cdot (' +
                  ComplexFormatter.latex(C2.conjugate(), _currentFormat, precision: 2) +
                  r')}{' +
                  _texNum(denominatorCp) +
                  r'}',
            ),
          );
          circleSteps.add(_texScroll(r'= ' + ComplexFormatter.latexHybrid(Cp, precision: 3)));
          circleSteps.add(const Divider());

          circleSteps.add(_text('3. Radius (rp):', bold: true));
          circleSteps.add(_texScroll(r'r_p = \frac{\sqrt{...}}{' + _texNum(denominatorCp.abs()) + r'} = ' + _texNum(rp)));

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

        // 4) Simultaneous conjugate match (only if unconditionally stable)
        if (_isUnconditionallyStable) {
          final B1 = 1 + S11abs2 - S22abs2 - deltaAbs2;
          final B2 = 1 + S22abs2 - S11abs2 - deltaAbs2;
          final C1 = S11 - delta * S22.conjugate();

          final discrim1 = B1 * B1 - 4 * C1.modulus * C1.modulus;
          final discrim2 = B2 * B2 - 4 * C2.modulus * C2.modulus;

          final twoC1 = C1 * Complex(2, 0);
          final twoC2 = C2 * Complex(2, 0);

          if (discrim1 >= 0 && discrim2 >= 0 && twoC1.modulus > 1e-9 && twoC2.modulus > 1e-9) {
            Complex Gms = Complex(B1 - sqrt(discrim1), 0) / twoC1;
            if (Gms.modulus > 1) Gms = Complex(B1 + sqrt(discrim1), 0) / twoC1;

            Complex Gml = Complex(B2 - sqrt(discrim2), 0) / twoC2;
            if (Gml.modulus > 1) Gml = Complex(B2 + sqrt(discrim2), 0) / twoC2;

            _stepPanels.add(
              StepPanel(
                title: '4. Simultaneous Conjugate Match',
                content: [
                  _text('Since K > 1, simultaneous conjugate match exists.'),
                  _text('Formulas:', bold: true),
                  _texScroll(r'\Gamma_{Ms} = \frac{B_1 \pm \sqrt{B_1^2 - 4|C_1|^2}}{2C_1}'),
                  _texScroll(r'\Gamma_{ML} = \frac{B_2 \pm \sqrt{B_2^2 - 4|C_2|^2}}{2C_2}'),
                  _text('Results:', bold: true),
                  _texScroll(r'\Gamma_{Ms} = ' + ComplexFormatter.latexHybrid(Gms, precision: 3)),
                  _texScroll(r'\Gamma_{ML} = ' + ComplexFormatter.latexHybrid(Gml, precision: 3)),
                ],
              ),
            );
          }
        } else {
          _stepPanels.add(
            StepPanel(
              title: '4. Conjugate Match Analysis',
              content: [
                _text('Device is potentially unstable.', bold: true),
                _text('Simultaneous conjugate match is not guaranteed.'),
              ],
            ),
          );
        }

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

  // ==========================================
  // Build
  // ==========================================
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
                                TextSpan(text: "Assumes "),
                                TextSpan(text: "S12 ≠ 0", style: TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: ". Input and Output matching are coupled."),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Example bar (matches Unilateral style)
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

              // Inputs
              ComplexInputRow(format: _currentFormat, ctrl1: s11C1, ctrl2: s11C2, paramName: 'S11', validator: commonValidator),
              ComplexInputRow(format: _currentFormat, ctrl1: s12C1, ctrl2: s12C2, paramName: 'S12', validator: commonValidator),
              ComplexInputRow(format: _currentFormat, ctrl1: s21C1, ctrl2: s21C2, paramName: 'S21', validator: commonValidator),
              ComplexInputRow(format: _currentFormat, ctrl1: s22C1, ctrl2: s22C2, paramName: 'S22', validator: commonValidator),

              const SizedBox(height: 12),
              _buildScalarInput(z0C, 'Z0 (Ohm)', validator: commonValidator),

              const SizedBox(height: 12),
              TextFormField(
                controller: gainDbListC,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
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
                    return ExpansionPanel(
                      headerBuilder: (context, isExpanded) => ListTile(
                        title: Text(
                          entry.value.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isErrorPanel ? Colors.red : (isExpanded ? Colors.deepPurple : Colors.black87),
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
