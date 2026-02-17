import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:equations/equations.dart';

import '../functional_components/menu_functions.dart';
import '../input_and_output_functions/utils.dart';
import '../functional_components/fixed_input.dart';
import '../smith_chart_db_module/smith_gain_circle_painter.dart';

class GainCircleExamplePreset {
  final String name;

  // scalar
  final String z0;
  final String gainDbList;

  // S params (mag/angle DEG)
  final String s11Mag, s11Ang;
  final String s21Mag, s21Ang;
  final String s22Mag, s22Ang;

  const GainCircleExamplePreset({
    required this.name,
    required this.z0,
    required this.gainDbList,
    required this.s11Mag,
    required this.s11Ang,
    required this.s21Mag,
    required this.s21Ang,
    required this.s22Mag,
    required this.s22Ang,
  });
}

class GainCirclePage extends StatefulWidget {
  const GainCirclePage({super.key});

  @override
  State<GainCirclePage> createState() => _GainCirclePageState();
}

class _GainCirclePageState extends State<GainCirclePage> {
  final _formKey = GlobalKey<FormState>();

  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  ComplexInputFormat _currentFormat = ComplexInputFormat.polarDegree;

  final s11C1 = TextEditingController(text: '0.8');
  final s11C2 = TextEditingController(text: '-80');
  final s21C1 = TextEditingController(text: '2');
  final s21C2 = TextEditingController(text: '0');
  final s22C1 = TextEditingController(text: '0.8');
  final s22C2 = TextEditingController(text: '-80');
  final s12C1 = TextEditingController(text: '0');
  final s12C2 = TextEditingController(text: '0');

  final z0C = TextEditingController(text: '50');
  final gainDbListC = TextEditingController(text: '3, 2, 1, 0, -1');

  bool _hasCalculated = false;
  String? _errorMessage;

  Complex? _s11, _s22, _s21;
  List<double>? _targetGains;

  double _z0Used = 50.0;

  Timer? _debounce;

  // =========================================================
  // 示例列表
  // =========================================================
  late final List<GainCircleExamplePreset> _examples = [
    const GainCircleExamplePreset(
      name: 'Example 4-3 (500 MHz, Unilateral)',
      z0: '50',
      gainDbList: '3, 2, 1, 0, -1',
      s11Mag: '0.8',
      s11Ang: '-80',
      s21Mag: '2',
      s21Ang: '0',
      s22Mag: '0.8',
      s22Ang: '-80',
    ),
    const GainCircleExamplePreset(
      name: 'Example 4-3 Variant (phase changed)',
      z0: '50',
      gainDbList: '3, 2, 1, 0, -1',
      s11Mag: '0.8',
      s11Ang: '-120',
      s21Mag: '2',
      s21Ang: '10',
      s22Mag: '0.8',
      s22Ang: '-40',
    ),
    const GainCircleExamplePreset(
      name: 'Example 4-7 (3 GHz, Unilateral, G = 15 dB)',
      z0: '50',
      gainDbList: '0, 1, 2',
      s11Mag: '0.707',
      s11Ang: '-155',
      s21Mag: '4',
      s21Ang: '180',
      s22Mag: '0.51',
      s22Ang: '-20',
    ),
    const GainCircleExamplePreset(
      name: 'Example 4-9 (1 GHz, Unilateral, G = 16 dB)',
      z0: '50',
      gainDbList: '0, 1, 2',
      s11Mag: '0.707',
      s11Ang: '-155',
      s21Mag: '5',
      s21Ang: '180',
      s22Mag: '0.51',
      s22Ang: '-20',
    ),
    const GainCircleExamplePreset(
      name: 'Normal Passive Ports (|S11|,|S22| small)',
      z0: '',
      gainDbList: '6, 4, 2, 0, -2',
      s11Mag: '0.35',
      s11Ang: '-50',
      s21Mag: '2.2',
      s21Ang: '70',
      s22Mag: '0.25',
      s22Ang: '-20',
    ),
    const GainCircleExamplePreset(
      name: 'Edge Case: |S11| ~ 0.999 (near singular)',
      z0: '',
      gainDbList: '3, 2, 1, 0, -1',
      s11Mag: '0.999',
      s11Ang: '-80',
      s21Mag: '2',
      s21Ang: '0',
      s22Mag: '0.8',
      s22Ang: '-80',
    ),
    const GainCircleExamplePreset(
      name: 'Edge Case: |S22| ~ 0.999 (near singular)',
      z0: '',
      gainDbList: '3, 2, 1, 0, -1',
      s11Mag: '0.8',
      s11Ang: '-80',
      s21Mag: '2',
      s21Ang: '0',
      s22Mag: '0.999',
      s22Ang: '-80',
    ),
    const GainCircleExamplePreset(
      name: 'Error Test: Input Unstable (|S11| >= 1)',
      z0: '',
      gainDbList: '3, 2, 1, 0, -1',
      s11Mag: '1.05',
      s11Ang: '-30',
      s21Mag: '2',
      s21Ang: '0',
      s22Mag: '0.8',
      s22Ang: '-80',
    ),
    const GainCircleExamplePreset(
      name: 'Error Test: Output Unstable (|S22| >= 1)',
      z0: '',
      gainDbList: '3, 2, 1, 0, -1',
      s11Mag: '0.8',
      s11Ang: '-80',
      s21Mag: '2',
      s21Ang: '0',
      s22Mag: '1.05',
      s22Ang: '-10',
    ),
    const GainCircleExamplePreset(
      name: 'Error Test: Zero Forward Gain (|S21| ≈ 0)',
      z0: '',
      gainDbList: '3, 2, 1, 0, -1',
      s11Mag: '0.8',
      s11Ang: '-80',
      s21Mag: '0',
      s21Ang: '0',
      s22Mag: '0.8',
      s22Ang: '-80',
    ),
    const GainCircleExamplePreset(
      name: 'Table Test: Gain targets too high',
      z0: '',
      gainDbList: '20, 15, 10, 5, 0',
      s11Mag: '0.8',
      s11Ang: '-80',
      s21Mag: '2',
      s21Ang: '0',
      s22Mag: '0.8',
      s22Ang: '-80',
    ),
  ];

  int _exampleIndex = 0;

  void _scheduleAutoCalc() {
    if (_autoValidateMode != AutovalidateMode.onUserInteraction) {
      setState(() => _autoValidateMode = AutovalidateMode.onUserInteraction);
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _onCalculatePressed();
    });
  }

  void _forceCalcFromTapBlank() {
    FocusScope.of(context).unfocus();
    _onCalculatePressed();
  }

  void _applyExample(GainCircleExamplePreset ex) {
    _currentFormat = ComplexInputFormat.polarDegree;

    z0C.text = ex.z0;
    gainDbListC.text = ex.gainDbList;

    s11C1.text = ex.s11Mag;
    s11C2.text = ex.s11Ang;

    s21C1.text = ex.s21Mag;
    s21C2.text = ex.s21Ang;

    s22C1.text = ex.s22Mag;
    s22C2.text = ex.s22Ang;

    s12C1.text = '0';
    s12C2.text = '0';
  }

  void _nextExampleAndRecalculate() {
    setState(() {
      _exampleIndex = (_exampleIndex + 1) % _examples.length;

      _hasCalculated = false;
      _errorMessage = null;
      _s11 = null;
      _s21 = null;
      _s22 = null;
      _targetGains = null;

      _applyExample(_examples[_exampleIndex]);
    });

    _onCalculatePressed();
  }

  void _previousExampleAndRecalculate() {
    setState(() {
      _exampleIndex = (_exampleIndex - 1 + _examples.length) % _examples.length;

      _hasCalculated = false;
      _errorMessage = null;
      _s11 = null;
      _s21 = null;
      _s22 = null;
      _targetGains = null;

      _applyExample(_examples[_exampleIndex]);
    });

    _onCalculatePressed();
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

  Complex _parseComplex(TextEditingController c1, TextEditingController c2) {
    final inputStr = _joinInput(c1, c2);
    return ComplexParser.parseUniversal(inputStr, _currentFormat);
  }

  void switchAllFormat(ComplexInputFormat newFormat) {
    if (newFormat == _currentFormat) return;

    setState(() {
      void convert(TextEditingController c1, TextEditingController c2) {
        final c = _parseComplex(c1, c2);
        if (newFormat == ComplexInputFormat.cartesian) {
          c1.text = ComplexFormatter.smartFormat(c.real, useScientific: false, precision: 6);
          c2.text = ComplexFormatter.smartFormat(c.imaginary, useScientific: false, precision: 6);
        } else {
          c1.text = ComplexFormatter.smartFormat(c.modulus, useScientific: false, precision: 6);
          final angle = (newFormat == ComplexInputFormat.polarDegree) ? c.phase() * 180 / pi : c.phase();
          c2.text = ComplexFormatter.smartFormat(angle, useScientific: false, precision: 6);
        }
      }

      convert(s11C1, s11C2);
      convert(s21C1, s21C2);
      convert(s22C1, s22C2);

      _currentFormat = newFormat;
    });

    _onCalculatePressed();
  }

  void _onCalculatePressed() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() {
      _hasCalculated = false;
      _errorMessage = null;
    });

    try {
      final s11 = _parseComplex(s11C1, s11C2);
      final s21 = _parseComplex(s21C1, s21C2);
      final s22 = _parseComplex(s22C1, s22C2);
      final z0Text = z0C.text.trim();
      final z0Used = (z0Text.isEmpty) ? 50.0 : double.parse(z0Text);

      if (s21.modulus < 1e-9) {
        setState(() {
          _hasCalculated = true;
          _errorMessage = "Zero Forward Gain Detected (|S21| ≈ 0).\nDevice cannot amplify.";
        });
        return;
      }

      if (s11.modulus >= 1.0 - 1e-9) {
        setState(() {
          _hasCalculated = true;
          _errorMessage =
          "Input Instability Detected (|S11| ≥ 1).\nUnilateral Max Gain is undefined.\nPlease use Stability Circles instead.";
        });
        return;
      }
      if (s22.modulus >= 1.0 - 1e-9) {
        setState(() {
          _hasCalculated = true;
          _errorMessage =
          "Output Instability Detected (|S22| ≥ 1).\nUnilateral Max Gain is undefined.\nPlease use Stability Circles instead.";
        });
        return;
      }

      final gains = gainDbListC.text
          .split(',')
          .map((e) => double.tryParse(e.trim()) ?? 0.0)
          .toList();

      setState(() {
        _s11 = s11;
        _s21 = s21;
        _s22 = s22;
        _targetGains = gains;

        _z0Used = z0Used;

        _hasCalculated = true;
      });
    } catch (e) {
      setState(() {
        _hasCalculated = true;
        _errorMessage = "Input Error: $e";
      });
    }
  }

  Widget _buildLockedS12Row() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Text(
            "S12",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.deepPurple.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_off, size: 18, color: Colors.deepPurple.shade400),
                const SizedBox(width: 8),
                Text(
                  "0.0 ∠ 0° (Fixed)",
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Tooltip(
            message: "No Reverse Transmission (Unilateral)",
            child: Icon(Icons.help_outline, size: 20, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPanel() {
    return Card(
      color: Colors.red[50],
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Calculation Error",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? "Unknown Error",
              style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.5),
            ),
          ],
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
      autovalidateMode: _autoValidateMode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onChanged: (_) => _scheduleAutoCalc(),
      onFieldSubmitted: (_) => _onCalculatePressed(),
      onEditingComplete: () => _onCalculatePressed(),
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
    _exampleIndex = 0;
    _applyExample(_examples[_exampleIndex]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    s11C1.dispose();
    s11C2.dispose();
    s21C1.dispose();
    s21C2.dispose();
    s22C1.dispose();
    s22C2.dispose();
    s12C1.dispose();
    s12C2.dispose();
    z0C.dispose();
    gainDbListC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ex = _examples[_exampleIndex];

    return CommonScaffold(
      title: 'Unilateral Gain Circles',
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _forceCalcFromTapBlank,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: _autoValidateMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Unilateral Mode (S12 = 0)",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Feedback is assumed to be zero. Input and Output matching are decoupled.",
                              style: TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Card(
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 520; // 阈值

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
                              children: [prevBtn, nextBtn],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _buildFormatBtn('Cartesian (a+bj)', ComplexInputFormat.cartesian),
                    const SizedBox(width: 8),
                    _buildFormatBtn('Polar (deg)', ComplexInputFormat.polarDegree),
                    const SizedBox(width: 8),
                    _buildFormatBtn('Polar (rad)', ComplexInputFormat.polarRadian),
                  ]),
                ),
                const SizedBox(height: 20),

                ComplexInputRow(
                  format: _currentFormat,
                  ctrl1: s11C1,
                  ctrl2: s11C2,
                  paramName: 'S11',
                  validator: commonValidator,
                  onAnyChanged: _scheduleAutoCalc,
                  onSubmit: _onCalculatePressed,
                  action1: TextInputAction.next,
                  action2: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                _buildLockedS12Row(),
                const SizedBox(height: 12),

                ComplexInputRow(
                  format: _currentFormat,
                  ctrl1: s21C1,
                  ctrl2: s21C2,
                  paramName: 'S21',
                  validator: commonValidator,
                  onAnyChanged: _scheduleAutoCalc,
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
                  onAnyChanged: _scheduleAutoCalc,
                  onSubmit: _onCalculatePressed,
                  action1: TextInputAction.next,
                  action2: TextInputAction.done,
                ),

                const SizedBox(height: 12),

                Row(children: [
                  Expanded(
                    child: _buildScalarInput(
                      z0C,
                      'Z0 (Ω)',
                      validator: (val) {
                        final s = (val ?? '').trim();
                        if (s.isEmpty) return null;
                        return commonValidator(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: gainDbListC,
                      validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                      autovalidateMode: _autoValidateMode,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => _scheduleAutoCalc(),
                      onFieldSubmitted: (_) => _onCalculatePressed(),
                      onEditingComplete: () => _onCalculatePressed(),
                      decoration: const InputDecoration(
                        labelText: 'Target Gains (dB)',
                        hintText: 'e.g. 3, 2, 1, 0',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        isDense: true,
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _onCalculatePressed,
                    icon: const Icon(Icons.calculate),
                    label: const Text('Calculate Unilateral Circles', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),

                if (_hasCalculated) ...[
                  if (_errorMessage != null)
                    _buildErrorPanel()
                  else if (_s11 != null) ...[
                    _UnilateralMaxGainSection(s11: _s11!, s21: _s21!, s22: _s22!),
                    const SizedBox(height: 16),
                    InputGainSection(s11: _s11!, targetGains: _targetGains!, currentFormat: _currentFormat),
                    const SizedBox(height: 16),
                    OutputGainSection(s22: _s22!, targetGains: _targetGains!, currentFormat: _currentFormat),
                  ],
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

// 模块 1: 单向最大增益汇总
class _UnilateralMaxGainSection extends StatelessWidget {
  final Complex s11, s21, s22;

  const _UnilateralMaxGainSection({
    required this.s11,
    required this.s21,
    required this.s22,
  });

  String _texNum(double val) => ComplexFormatter.smartFormat(val, useLatex: true);
  double toDb(double x) => (x <= 0) ? -999 : 10 * log(x) / ln10;
  Widget _texScroll(String latex) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Math.tex(latex, textStyle: const TextStyle(fontSize: 15, color: Colors.black87)),
  );

  @override
  Widget build(BuildContext context) {
    final s11Abs = s11.modulus;
    final s22Abs = s22.modulus;
    final s21Abs = s21.modulus;

    final bool inputStable = s11Abs < 1.0;
    final bool outputStable = s22Abs < 1.0;
    final bool isUnconditionallyStable = inputStable && outputStable;

    if (!isUnconditionallyStable) {
      return Card(
        color: Colors.orange[50],
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "⚠️ Potential Instability Detected",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text("Input Port: ${inputStable ? 'Stable' : 'Unstable (|S11|=${_texNum(s11Abs)} > 1)'}"),
              Text("Output Port: ${outputStable ? 'Stable' : 'Unstable (|S22|=${_texNum(s22Abs)} > 1)'}"),
            ],
          ),
        ),
      );
    }

    final s11Abs2 = s11Abs * s11Abs;
    final s22Abs2 = s22Abs * s22Abs;
    final s21Abs2 = s21Abs * s21Abs;

    final gsMax = 1 / (1 - s11Abs2);
    final glMax = 1 / (1 - s22Abs2);
    final g0 = s21Abs2;

    final gtuMax = gsMax * g0 * glMax;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Math.tex(
          r'\textbf{1.\;Maximum\;Unilateral\;Transducer\;Gain}',
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
        ),
        initiallyExpanded: false,
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.grey[50],
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _texScroll(r'G_{TU,max} = G_{s,max} \cdot G_0 \cdot G_{L,max}'),
                const SizedBox(height: 12),
                const Text("A. Max Source Gain (Input Match):", style: TextStyle(fontWeight: FontWeight.bold)),
                _texScroll(
                  r'G_{s,max} = \frac{1}{1-|S_{11}|^2} = \frac{1}{1-' +
                      _texNum(s11Abs2) +
                      r'} = \mathbf{' +
                      _texNum(gsMax) +
                      r'} \quad (' +
                      _texNum(toDb(gsMax)) +
                      r'\text{ dB})',
                ),
                const Text("B. Transistor Intrinsic Gain:", style: TextStyle(fontWeight: FontWeight.bold)),
                _texScroll(
                  r'G_0 = |S_{21}|^2 = ' +
                      _texNum(s21Abs2) +
                      r' \quad (' +
                      _texNum(toDb(g0)) +
                      r'\text{ dB})',
                ),
                const Text("C. Max Load Gain (Output Match):", style: TextStyle(fontWeight: FontWeight.bold)),
                _texScroll(
                  r'G_{L,max} = \frac{1}{1-|S_{22}|^2} = \frac{1}{1-' +
                      _texNum(s22Abs2) +
                      r'} = \mathbf{' +
                      _texNum(glMax) +
                      r'} \quad (' +
                      _texNum(toDb(glMax)) +
                      r'\text{ dB})',
                ),
                const Divider(),
                const Text("Total Maximum Gain:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                _texScroll(
                  r'G_{TU,max} = ' +
                      _texNum(gsMax) +
                      r' \cdot ' +
                      _texNum(g0) +
                      r' \cdot ' +
                      _texNum(glMax) +
                      r' = \mathbf{' +
                      _texNum(gtuMax) +
                      r'}',
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    "In dB: ${_texNum(toDb(gsMax))} + ${_texNum(toDb(g0))} + ${_texNum(toDb(glMax))} = ${_texNum(toDb(gtuMax))} dB",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 模块 2: 输入增益圆
class InputGainSection extends StatefulWidget {
  final Complex s11;
  final List<double> targetGains;
  final ComplexInputFormat currentFormat;

  const InputGainSection({super.key, required this.s11, required this.targetGains, required this.currentFormat});

  @override
  State<InputGainSection> createState() => _InputGainSectionState();
}

class _InputGainSectionState extends State<InputGainSection> {
  List<bool> _expanded = [];

  String _texNum(double val) => ComplexFormatter.smartFormat(val, useLatex: true);

  // 辅助函数：转dB
  double _toDb(double lin) => (lin <= 1e-9) ? -999 : 10 * log(lin) / ln10;

  Widget _subHeader(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 2),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
  );
  Widget _texScroll(String latex) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Math.tex(latex, textStyle: const TextStyle(fontSize: 15, color: Colors.black87)),
  );

  @override
  Widget build(BuildContext context) {
    final s11Abs = widget.s11.modulus;
    final s11Abs2 = s11Abs * s11Abs;
    final denomMax = 1 - s11Abs2;
    final gsMax = (denomMax <= 0) ? 1e9 : 1 / denomMax;

    // 计算最大增益的 dB 值，用于显示
    final gsMaxDb = _toDb(gsMax);

    List<GainCircleData> circles = [];
    List<List<String>> tableData = [];

    if (_expanded.length != widget.targetGains.length) {
      _expanded = List.filled(widget.targetGains.length, false);
    }

    for (int i = 0; i < widget.targetGains.length; i++) {
      double G_db = widget.targetGains[i];
      double G_lin = pow(10, G_db / 10).toDouble();

      bool exceedsMax = (G_lin > gsMax * 1.0001);

      if (exceedsMax) {
        tableData.add([_texNum(G_db), "> Max (${_texNum(gsMaxDb)}dB)", "-", "-"]);
        continue;
      }

      double g_s = G_lin / gsMax;
      double denom = 1 - s11Abs2 * (1 - g_s);
      if (denom.abs() < 1e-9) denom = 1e-9;

      double d_mag = (g_s * s11Abs) / denom;
      Complex d = Complex.fromPolar(r: d_mag, theta: -widget.s11.phase());

      double r_sq_inner = 1 - g_s;
      double r = (sqrt(max(0, r_sq_inner)) * (1 - s11Abs2)) / denom;

      circles.add(GainCircleData(center: d, radius: r, label: '${_texNum(G_db)}dB', color: Colors.blueAccent));
      tableData.add([
        _texNum(G_db),
        _texNum(g_s),
        ComplexFormatter.latex(d, widget.currentFormat, precision: 3),
        _texNum(r),
      ]);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Math.tex(
          r'\textbf{2.\;Input\;Gain\;Circles}\;(G_s)',
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
        ),
        initiallyExpanded: false,
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.grey[50],
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (circles.isNotEmpty)
                  Center(
                    child: SizedBox(
                      height: 320,
                      width: 320,
                      child: SmithGainCirclePainter(gainCircles: circles, canvasSize: 320),
                    ),
                  ),
                const SizedBox(height: 16),

                const Text("Summary Table:", style: TextStyle(fontWeight: FontWeight.bold)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('Gs(dB)')),
                      DataColumn(label: Text('gs')),
                      DataColumn(label: Text('Center')),
                      DataColumn(label: Text('Radius')),
                    ],
                    rows: tableData.map((row) {
                      bool isError = row[1].startsWith("> Max");
                      return DataRow(
                        cells: row.map((c) {
                          if (c.contains(r'\')) {
                            return DataCell(Math.tex(c, textStyle: TextStyle(color: isError ? Colors.red : Colors.black)));
                          }
                          return DataCell(Text(
                            c,
                            style: TextStyle(
                              color: isError ? Colors.red : Colors.black,
                              fontWeight: isError ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ));
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                const Text("Detailed Steps (Tap to expand):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(height: 8),

                ExpansionPanelList(
                  elevation: 1,
                  expansionCallback: (panelIndex, isExpanded) {
                    setState(() {
                      _expanded[panelIndex] = !_expanded[panelIndex];
                    });
                  },
                  children: widget.targetGains.asMap().entries.map((entry) {
                    int index = entry.key;
                    double G_db = entry.value;
                    double G_lin = pow(10, G_db / 10).toDouble();

                    bool exceedsMax = (G_lin > gsMax * 1.0001);
                    double g_s = G_lin / gsMax;

                    double denom = 1 - s11Abs2 * (1 - g_s);
                    if (denom.abs() < 1e-9) denom = 1e-9;
                    double d_mag = (g_s * s11Abs) / denom;
                    double r_sq_inner = 1 - g_s;

                    String angleSymbol = (widget.currentFormat == ComplexInputFormat.polarDegree) ? r'^\circ' : r' \text{ rad}';
                    double angleVal = (widget.currentFormat == ComplexInputFormat.polarDegree)
                        ? -widget.s11.phase() * 180 / pi
                        : -widget.s11.phase();

                    return ExpansionPanel(
                      headerBuilder: (context, isExpanded) {
                        if (exceedsMax) {
                          return ListTile(
                            title: Text(
                              'Target Gs (${_texNum(G_db)} dB) > Max (${_texNum(gsMaxDb)} dB)',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                            leading: const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          );
                        }
                        return ListTile(
                          title: Text(
                            'Circle ${index + 1}: Target Gs = $G_db dB',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        );
                      },
                      body: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (exceedsMax)
                              Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  "Invalid: The target gain ($G_db dB) is theoretically impossible because it exceeds the Maximum Available Source Gain ($gsMaxDb dB).",
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, height: 1.4),
                                ),
                              ),
                            _subHeader("1. Normalized Gain (gs):"),
                            _texScroll(r'\text{Formula: } g_s = \frac{G_s}{G_{s,max}}'),
                            _texScroll(
                              r'\text{Substitution: } g_s = \frac{10^{' +
                                  _texNum(G_db) +
                                  r'/10}}{' +
                                  _texNum(gsMax) +
                                  r'} = \frac{' +
                                  _texNum(G_lin) +
                                  r'}{' +
                                  _texNum(gsMax) +
                                  r'}',
                            ),
                            _texScroll(r'\text{Result: } g_s = ' + _texNum(g_s)),
                            if (!exceedsMax) ...[
                              const Divider(),
                              _subHeader("2. Center Distance (d):"),
                              _texScroll(r'\text{Formula: } d_{g_s} = \frac{g_s |S_{11}|}{1 - |S_{11}|^2 (1-g_s)}'),
                              _texScroll(
                                r'\text{Substitution: } d_{g_s} = \frac{' +
                                    _texNum(g_s) +
                                    r' \cdot ' +
                                    _texNum(s11Abs) +
                                    r'}{1 - ' +
                                    _texNum(s11Abs2) +
                                    r'(1 - ' +
                                    _texNum(g_s) +
                                    r')}',
                              ),
                              _texScroll(r'\text{Result (Scalar): } d_{g_s} = ' + _texNum(d_mag)),
                              _texScroll(
                                r'\text{Result (Complex): } C_{g_s} = d_{g_s} \angle S_{11}^* = ' +
                                    _texNum(d_mag) +
                                    r' \angle ' +
                                    _texNum(angleVal) +
                                    angleSymbol,
                              ),
                              const Divider(),
                              _subHeader("3. Radius (r):"),
                              _texScroll(r'\text{Formula: } r_{g_s} = \frac{\sqrt{1-g_s}(1-|S_{11}|^2)}{1 - |S_{11}|^2 (1-g_s)}'),
                              _texScroll(
                                r'\text{Substitution: } r_{g_s} = \frac{\sqrt{1-' +
                                    _texNum(g_s) +
                                    r'}(1-' +
                                    _texNum(s11Abs2) +
                                    r')}{' +
                                    _texNum(denom) +
                                    r'}',
                              ),
                              _texScroll(
                                r'\text{Result: } r_{g_s} = ' + _texNum((sqrt(max(0, r_sq_inner)) * (1 - s11Abs2)) / denom),
                              ),
                            ],
                          ],
                        ),
                      ),
                      isExpanded: _expanded[index],
                      canTapOnHeader: true,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 模块 3: 输出增益圆
class OutputGainSection extends StatefulWidget {
  final Complex s22;
  final List<double> targetGains;
  final ComplexInputFormat currentFormat;

  const OutputGainSection({super.key, required this.s22, required this.targetGains, required this.currentFormat});

  @override
  State<OutputGainSection> createState() => _OutputGainSectionState();
}

class _OutputGainSectionState extends State<OutputGainSection> {
  List<bool> _expanded = [];

  String _texNum(double val) => ComplexFormatter.smartFormat(val, useLatex: true);

  // 辅助函数：转dB
  double _toDb(double lin) => (lin <= 1e-9) ? -999 : 10 * log(lin) / ln10;

  Widget _texScroll(String latex) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Math.tex(latex, textStyle: const TextStyle(fontSize: 15, color: Colors.black87)),
  );
  Widget _subHeader(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 2),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  @override
  Widget build(BuildContext context) {
    final s22Abs = widget.s22.modulus;
    final s22Abs2 = s22Abs * s22Abs;
    final denomMax = 1 - s22Abs2;
    final glMax = (denomMax <= 0) ? 1e9 : 1 / denomMax;

    // 计算最大增益 dB
    final glMaxDb = _toDb(glMax);

    List<GainCircleData> circles = [];
    List<List<String>> tableData = [];

    if (_expanded.length != widget.targetGains.length) {
      _expanded = List.filled(widget.targetGains.length, false);
    }

    for (int i = 0; i < widget.targetGains.length; i++) {
      double G_db = widget.targetGains[i];
      double G_lin = pow(10, G_db / 10).toDouble();

      bool exceedsMax = (G_lin > glMax * 1.0001);

      if (exceedsMax) {
        tableData.add([_texNum(G_db), "> Max (${_texNum(glMaxDb)}dB)", "-", "-"]);
        continue;
      }

      double g_l = G_lin / glMax;
      double denom = 1 - s22Abs2 * (1 - g_l);
      if (denom.abs() < 1e-9) denom = 1e-9;

      double d_mag = (g_l * s22Abs) / denom;
      Complex d = Complex.fromPolar(r: d_mag, theta: -widget.s22.phase());
      double r_sq_inner = 1 - g_l;
      double r = (sqrt(max(0, r_sq_inner)) * (1 - s22Abs2)) / denom;

      circles.add(GainCircleData(center: d, radius: r, label: '${_texNum(G_db)}dB', color: Colors.redAccent));
      tableData.add([
        _texNum(G_db),
        _texNum(g_l),
        ComplexFormatter.latex(d, widget.currentFormat, precision: 3),
        _texNum(r),
      ]);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Math.tex(
          r'\textbf{3.\;Output\;Gain\;Circles}\;(G_L)',
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
        ),
        initiallyExpanded: false,
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.grey[50],
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (circles.isNotEmpty)
                  Center(
                    child: SizedBox(
                      height: 320,
                      width: 320,
                      child: SmithGainCirclePainter(gainCircles: circles, canvasSize: 320),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text("Summary Table:", style: TextStyle(fontWeight: FontWeight.bold)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('GL(dB)')),
                      DataColumn(label: Text('gL')),
                      DataColumn(label: Text('Center')),
                      DataColumn(label: Text('Radius')),
                    ],
                    rows: tableData.map((row) {
                      bool isError = row[1].startsWith("> Max");
                      return DataRow(
                        cells: row.map((c) {
                          if (c.contains(r'\')) {
                            return DataCell(Math.tex(c, textStyle: TextStyle(color: isError ? Colors.red : Colors.black)));
                          }
                          return DataCell(Text(
                            c,
                            style: TextStyle(
                              color: isError ? Colors.red : Colors.black,
                              fontWeight: isError ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ));
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Detailed Steps (Tap to expand):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(height: 8),
                ExpansionPanelList(
                  elevation: 1,
                  expansionCallback: (panelIndex, isExpanded) {
                    setState(() {
                      _expanded[panelIndex] = !_expanded[panelIndex];
                    });
                  },
                  children: widget.targetGains.asMap().entries.map((entry) {
                    int index = entry.key;
                    double G_db = entry.value;
                    double G_lin = pow(10, G_db / 10).toDouble();

                    bool exceedsMax = (G_lin > glMax * 1.0001);
                    double g_l = G_lin / glMax;

                    double denom = 1 - s22Abs2 * (1 - g_l);
                    if (denom.abs() < 1e-9) denom = 1e-9;
                    double d_mag = (g_l * s22Abs) / denom;
                    double r_sq_inner = 1 - g_l;

                    String angleSymbol = (widget.currentFormat == ComplexInputFormat.polarDegree) ? r'^\circ' : r' \text{ rad}';
                    double angleVal = (widget.currentFormat == ComplexInputFormat.polarDegree)
                        ? -widget.s22.phase() * 180 / pi
                        : -widget.s22.phase();

                    return ExpansionPanel(
                      headerBuilder: (context, isExpanded) {
                        if (exceedsMax) {
                          return ListTile(
                            title: Text(
                              'Target GL (${_texNum(G_db)} dB) > Max (${_texNum(glMaxDb)} dB)',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                            leading: const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          );
                        }
                        return ListTile(
                          title: Text(
                            'Circle ${index + 1}: Target GL = $G_db dB',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        );
                      },
                      body: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (exceedsMax)
                              Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  "Invalid: The target gain ($G_db dB) is theoretically impossible because it exceeds the Maximum Available Load Gain ($glMaxDb dB).",
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, height: 1.4),
                                ),
                              ),
                            _subHeader("1. Normalized Gain (gL):"),
                            _texScroll(r'\text{Formula: } g_L = \frac{G_L}{G_{L,max}}'),
                            _texScroll(
                              r'\text{Substitution: } g_L = \frac{10^{' +
                                  _texNum(G_db) +
                                  r'/10}}{' +
                                  _texNum(glMax) +
                                  r'} = \frac{' +
                                  _texNum(G_lin) +
                                  r'}{' +
                                  _texNum(glMax) +
                                  r'}',
                            ),
                            _texScroll(r'\text{Result: } g_L = ' + _texNum(g_l)),
                            if (!exceedsMax) ...[
                              const Divider(),
                              _subHeader("2. Center Distance (d):"),
                              _texScroll(r'\text{Formula: } d_{g_L} = \frac{g_L |S_{22}|}{1 - |S_{22}|^2 (1-g_L)}'),
                              _texScroll(
                                r'\text{Substitution: } d_{g_L} = \frac{' +
                                    _texNum(g_l) +
                                    r' \cdot ' +
                                    _texNum(s22Abs) +
                                    r'}{1 - ' +
                                    _texNum(s22Abs2) +
                                    r'(1 - ' +
                                    _texNum(g_l) +
                                    r')}',
                              ),
                              _texScroll(r'\text{Result (Scalar): } d_{g_L} = ' + _texNum(d_mag)),
                              _texScroll(
                                r'\text{Result (Complex): } C_{g_L} = d_{g_L} \angle S_{22}^* = ' +
                                    _texNum(d_mag) +
                                    r' \angle ' +
                                    _texNum(angleVal) +
                                    angleSymbol,
                              ),
                              const Divider(),
                              _subHeader("3. Radius (r):"),
                              _texScroll(r'\text{Formula: } r_{g_L} = \frac{\sqrt{1-g_L}(1-|S_{22}|^2)}{1 - |S_{22}|^2 (1-g_L)}'),
                              _texScroll(
                                r'\text{Substitution: } r_{g_L} = \frac{\sqrt{1-' +
                                    _texNum(g_l) +
                                    r'}(1-' +
                                    _texNum(s22Abs2) +
                                    r')}{' +
                                    _texNum(denom) +
                                    r'}',
                              ),
                              _texScroll(
                                r'\text{Result: } r_{g_L} = ' + _texNum((sqrt(max(0, r_sq_inner)) * (1 - s22Abs2)) / denom),
                              ),
                            ],
                          ],
                        ),
                      ),
                      isExpanded: _expanded[index],
                      canTapOnHeader: true,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
