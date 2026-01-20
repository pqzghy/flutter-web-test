import 'package:flutter/material.dart';
import 'package:equations/equations.dart';
import 'dart:math';

// 工具与输入组件
import '../input_and_output_functions/utils.dart';
import '../functional_components/fixed_input.dart';
import '../functional_components/menu_functions.dart';

// 史密斯图与稳定性判断相关
import '../simple_smith_chart_stability_judgment_module/smith_chart_widget.dart';
import '../simple_smith_chart_stability_judgment_module/stability_circle_calculator.dart';
import '../simple_smith_chart_stability_judgment_module/stability_region_detector.dart';

// 数学公式
import 'package:flutter_math_fork/flutter_math.dart';

// =================== StepPanel结构体 ===================
class StepPanel {
  final String title;
  final List<Widget> content;
  StepPanel({required this.title, required this.content});
}

// =================== AmplifierCalculator（逻辑计算类） ===================
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

  /// 辅助：生成带滚动的 LaTeX 组件
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

  /// 辅助：生成普通文本
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

  // ⚡️ 核心工具：强制生成 LaTeX 格式的数字字符串
  String _texNum(double val) {
    return ComplexFormatter.smartFormat(val, useLatex: true);
  }

  List<StepPanel> buildStepPanels(ComplexInputFormat displayFormat) {
    final panels = <StepPanel>[];

    // --- Step 1: Reflection Coefficients ---
    final zsStr = ComplexFormatter.smartFormat(zs);
    final zlStr = ComplexFormatter.smartFormat(zl);
    final z0Str = ComplexFormatter.smartFormat(z0);

    final gammaS = Complex((zs - z0) / (zs + z0), 0);
    final gammaL = Complex((zl - z0) / (zl + z0), 0);

    panels.add(
      StepPanel(
        title: '1. Reflection Coefficients (Γs, ΓL)',
        content: [
          _text('Calculate normalized reflection coefficients based on Zs, ZL, Z0.'),
          _texScroll(r'Z_0 = ' + z0Str + r', \ \ \ Z_s = ' + zsStr + r', \ \ \ Z_L = ' + zlStr),
          _text('Formula:', bold: true),
          _texScroll(r'\Gamma = \frac{Z - Z_0}{Z + Z_0}'),
          _text('Substitution:', bold: true),
          _texScroll(
              r'\Gamma_s = \frac{' + zsStr + '-' + z0Str + '}{' + zsStr + '+' + z0Str + '}, \ \ \ \ ' +
                  r'\Gamma_L = \frac{' + zlStr + '-' + z0Str + '}{' + zlStr + '+' + z0Str + '}'
          ),

          const Divider(),
          _text('Result:', bold: true),
          _texScroll(r'\Gamma_s = ' + ComplexFormatter.latexHybrid(gammaS, precision: 4)),
          _texScroll(r'\Gamma_L = ' + ComplexFormatter.latexHybrid(gammaL, precision: 4)),
        ],
      ),
    );

    // --- Step 2: Delta ---
    final delta = s11 * s22 - s12 * s21;
    panels.add(
      StepPanel(
        title: '2. Determinant (Δ)',
        content: [
          _text('Formula:', bold: true),
          _texScroll(r'\Delta = S_{11} S_{22} - S_{12} S_{21}'),
          _text('Substitution:', bold: true),
          _texScroll(
              r'\Delta = (' + ComplexFormatter.latex(s11, displayFormat) + r')(' + ComplexFormatter.latex(s22, displayFormat) + r') - ' +
                  r'(' + ComplexFormatter.latex(s12, displayFormat) + r')(' + ComplexFormatter.latex(s21, displayFormat) + r')'
          ),
          const Divider(),
          _text('Result:', bold: true),
          _texScroll(r'\Delta = ' + ComplexFormatter.latexHybrid(delta, precision: 4)),
          _texScroll(r'|\Delta| = ' + _texNum(delta.modulus)),
        ],
      ),
    );

    // --- Step 3: Input/Output Gamma ---
    final numeratorIn = s12 * s21 * gammaL;
    final denominatorIn = Complex(1, 0) - s22 * gammaL;
    final gammaIn = s11 + numeratorIn / denominatorIn;

    final numeratorOut = s12 * s21 * gammaS;
    final denominatorOut = Complex(1, 0) - s11 * gammaS;
    final gammaOut = s22 + numeratorOut / denominatorOut;

    panels.add(
      StepPanel(
        title: '3. Input/Output Reflection (Γin, Γout)',
        content: [
          _text('Formula:', bold: true),
          _texScroll(r'\Gamma_{in} = S_{11} + \frac{S_{12} S_{21} \Gamma_L}{1 - S_{22} \Gamma_L}'),
          _text('Substitution:', bold: true),
          _texScroll(
              r'\Gamma_{in} = ' + ComplexFormatter.latex(s11, displayFormat) +
                  r' + \frac{(' + ComplexFormatter.latex(s12, displayFormat) + r')(' + ComplexFormatter.latex(s21, displayFormat) + r')(' + ComplexFormatter.latex(gammaL, displayFormat) + r')}' +
                  r'{1 - (' + ComplexFormatter.latex(s22, displayFormat) + r')(' + ComplexFormatter.latex(gammaL, displayFormat) + r')}'
          ),
          const Divider(),
          _text('Result:', bold: true),
          _texScroll(r'\Gamma_{in} = ' + ComplexFormatter.latexHybrid(gammaIn, precision: 4)),
          _texScroll(r'\Gamma_{out} = ' + ComplexFormatter.latexHybrid(gammaOut, precision: 4)),
        ],
      ),
    );

    // --- Step 4: Power Gains (Gt, Gp, Ga) ---
    final numeratorGt_Old = (1 - pow(gammaS.modulus, 2)) * pow(s21.modulus, 2) * (1 - pow(gammaL.modulus, 2));
    final denominatorGt_Old = (1 - pow(gammaIn.modulus, 2)) * (1 - pow(s22.modulus, 2));
    final gt = numeratorGt_Old / denominatorGt_Old;

    final numeratorGp = pow(s21.modulus, 2) * (1 - pow(gammaL.modulus, 2));
    final denominatorGp = (1 - pow(gammaIn.modulus, 2));
    final gp = numeratorGp / denominatorGp;

    final numeratorGa = pow(s21.modulus, 2) * (1 - pow(gammaS.modulus, 2));
    final denominatorGa = (1 - pow(gammaOut.modulus, 2));
    final ga = numeratorGa / denominatorGa;

    panels.add(
      StepPanel(
        title: '4. Power Gains (Gt, Gp, Ga)',
        content: [
          _text('Formula (Gt):', bold: true),
          _texScroll(r'G_t = \frac{(1 - |\Gamma_s|^2) |S_{21}|^2 (1 - |\Gamma_L|^2)}{(1 - |\Gamma_{in}|^2)(1 - |S_{22}|^2)}'),

          _text('Substitution:', bold: true),
          _texScroll(
              r'G_t = \frac{(1 - |' + _texNum(gammaS.modulus) + r'|^2) \cdot |' + _texNum(s21.modulus) + r'|^2 \cdot (1 - |' + _texNum(gammaL.modulus) + r'|^2)}' +
                  r'{(1 - |' + _texNum(gammaIn.modulus) + r'|^2)(1 - |' + _texNum(s22.modulus) + r'|^2)}'
          ),

          const Divider(),
          _text('Result:', bold: true),
          _texScroll(r'G_t = ' + _texNum(gt) + r' \quad (' + _texNum(10 * log(gt)/ln10) + r' \text{ dB})'),
          _text('Operating Power Gain (Gp) and Available Power Gain (Ga):'),
          _texScroll(r'G_p = ' + _texNum(gp) + r' \quad (' + _texNum(10 * log(gp)/ln10) + r' \text{ dB})'),
          _texScroll(r'G_a = ' + _texNum(ga) + r' \quad (' + _texNum(10 * log(ga)/ln10) + r' \text{ dB})'),
        ],
      ),
    );

    // --- Step 5: Stability (K, Delta) ---
    final numeratorK = 1 - pow(s11.modulus, 2) - pow(s22.modulus, 2) + pow(delta.modulus, 2);
    final denominatorK = 2 * s12.modulus * s21.modulus;
    final k = numeratorK / denominatorK;
    final isStable = (k > 1 && delta.modulus < 1);

    panels.add(
      StepPanel(
        title: '5. Stability Analysis (K, Δ)',
        content: [
          _text('Condition for unconditional stability: K > 1 and |Δ| < 1'),
          _text('Formula:', bold: true),
          _texScroll(r'K = \frac{1 - |S_{11}|^2 - |S_{22}|^2 + |\Delta|^2}{2|S_{12}||S_{21}|}'),

          _text('Substitution:', bold: true),
          _texScroll(
              r'K = \frac{1 - |' + _texNum(s11.modulus) + r'|^2 - |' + _texNum(s22.modulus) + r'|^2 + |' + _texNum(delta.modulus) + r'|^2}' +
                  r'{2 \cdot |' + _texNum(s12.modulus) + r'| \cdot |' + _texNum(s21.modulus) + r'|}'
          ),

          const Divider(),
          _text('Result:', bold: true),
          _texScroll(r'K = ' + _texNum(k)),
          _texScroll(r'|\Delta| = ' + _texNum(delta.modulus)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isStable ? Colors.green[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isStable ? Colors.green : Colors.orange),
            ),
            child: Text(
              isStable
                  ? "✅ Unconditionally Stable"
                  : "⚠️ Potentially Unstable",
              style: TextStyle(
                color: isStable ? Colors.green[800] : Colors.deepOrange[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return panels;
  }
}

// =================== 主页面 ===================
class AmplifierHomePage extends StatefulWidget {
  const AmplifierHomePage({super.key});

  @override
  State<AmplifierHomePage> createState() => _AmplifierHomePageState();
}

class _AmplifierHomePageState extends State<AmplifierHomePage> {
  // 频率
  final freqController = TextEditingController(text: '9');

  // 【已更新测试数据】：Pozar Example 11.2 (潜在不稳定 K<1)
  // 这组数据一定会触发红色警告并显示史密斯图
  final s11C1 = TextEditingController(text: '0.89');
  final s11C2 = TextEditingController(text: '-60.73');
  final s12C1 = TextEditingController(text: '0.02');
  final s12C2 = TextEditingController(text: '62.45');
  final s21C1 = TextEditingController(text: '3.12');
  final s21C2 = TextEditingController(text: '123.76');
  final s22C1 = TextEditingController(text: '0.78');
  final s22C2 = TextEditingController(text: '-27.50');

  // 阻抗
  final zsC = TextEditingController(text: '50');
  final zlC = TextEditingController(text: '50');
  final z0C = TextEditingController(text: '50');

  ComplexInputFormat _currentFormat = ComplexInputFormat.polarDegree;

  List<bool> _expandedList = [];
  List<StepPanel> _stepPanels = [];

  bool _sourceRegionExpanded = false;
  bool _loadRegionExpanded = false;
  Widget? _sourceRegionWidget;
  Widget? _loadRegionWidget;

  // 绘图数据
  Complex? sourceCenter, loadCenter;
  double? sourceRadius, loadRadius;
  double? s22Abs, s11Abs;
  bool isPotentiallyUnstableSource = false;
  bool isPotentiallyUnstableLoad = false;

  // 字符串拼接
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

      if (_stepPanels.isNotEmpty) calculate();
    });
  }

  void calculate() {
    final s11 = ComplexParser.parseUniversal(_joinInput(s11C1, s11C2), _currentFormat);
    final s12 = ComplexParser.parseUniversal(_joinInput(s12C1, s12C2), _currentFormat);
    final s21 = ComplexParser.parseUniversal(_joinInput(s21C1, s21C2), _currentFormat);
    final s22 = ComplexParser.parseUniversal(_joinInput(s22C1, s22C2), _currentFormat);

    final z0 = double.tryParse(z0C.text) ?? 50.0;
    final zs = double.tryParse(zsC.text) ?? 50.0;
    final zl = double.tryParse(zlC.text) ?? 50.0;

    final amplifier = AmplifierCalculator(
      s11: s11, s12: s12, s21: s21, s22: s22,
      zs: zs, zl: zl, z0: z0,
    );

    final stepPanels = amplifier.buildStepPanels(_currentFormat);

    if (_expandedList.length != stepPanels.length) {
      _expandedList = List.generate(stepPanels.length, (_) => false);
    }

    final delta = s11 * s22 - s12 * s21;
    final stability = StabilityCircleCalculator(
      s11: s11, s12: s12, s21: s21, s22: s22,
      delta: delta, z0: z0,
    ).calculate();

    sourceCenter = stability.sourceCenter;
    sourceRadius = stability.sourceRadius;
    loadCenter = stability.loadCenter;
    loadRadius = stability.loadRadius;
    s22Abs = s22.modulus;
    s11Abs = s11.modulus;

    double K = ((1 - pow(s11.modulus, 2) - pow(s22.modulus, 2) + pow(delta.modulus, 2)) /
        (2 * s12.modulus * s21.modulus));
    double deltaAbs = delta.modulus;

    bool isUnconditionallyStable = (K > 1 && deltaAbs < 1);
    isPotentiallyUnstableSource = !isUnconditionallyStable;
    isPotentiallyUnstableLoad = !isUnconditionallyStable;

    final region = StabilityRegionDetector(
      s11: s11, s12: s12, s21: s21, s22: s22, delta: delta,
    ).detect(stability, displayFormat: _currentFormat);

    Widget? srcWidget = region.isNotEmpty ? region[0] : null;
    Widget? loadWidget = region.length > 1 ? region[1] : null;

    setState(() {
      _stepPanels = stepPanels;

      // 【核心修改】：默认收缩 (改为 false)
      _sourceRegionExpanded = false;
      _loadRegionExpanded = false;

      _sourceRegionWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (srcWidget != null) srcWidget,
          if (isPotentiallyUnstableSource && sourceCenter != null)
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
        ],
      );

      _loadRegionWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loadWidget != null) loadWidget,
          if (isPotentiallyUnstableLoad && loadCenter != null)
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

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: 'Amplifier Full Flow Calculator',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),

            ComplexInputRow(format: _currentFormat, ctrl1: s11C1, ctrl2: s11C2, paramName: 'S11'),
            ComplexInputRow(format: _currentFormat, ctrl1: s12C1, ctrl2: s12C2, paramName: 'S12'),
            ComplexInputRow(format: _currentFormat, ctrl1: s21C1, ctrl2: s21C2, paramName: 'S21'),
            ComplexInputRow(format: _currentFormat, ctrl1: s22C1, ctrl2: s22C2, paramName: 'S22'),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: TextField(controller: freqController, decoration: const InputDecoration(labelText: 'Freq (GHz)', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: z0C, decoration: const InputDecoration(labelText: 'Z0 (Ω)', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: zsC, decoration: const InputDecoration(labelText: 'Zs (Source)', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: zlC, decoration: const InputDecoration(labelText: 'Zl (Load)', border: OutlineInputBorder()))),
              ],
            ),

            const SizedBox(height: 24),
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

            const SizedBox(height: 24),

            if (_stepPanels.isNotEmpty)
              ExpansionPanelList(
                expansionCallback: (panelIndex, isExpanded) {
                  setState(() {
                    _expandedList[panelIndex] = !_expandedList[panelIndex];
                  });
                },
                children: _stepPanels.asMap().entries.map((entry) {
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
                    isExpanded: _expandedList[entry.key],
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
                      leading: Icon(Icons.warning_amber_rounded, color: isPotentiallyUnstableSource ? Colors.orange : Colors.green),
                      title: Text('Source Stability Analysis', style: TextStyle(fontWeight: FontWeight.bold, color: isPotentiallyUnstableSource ? Colors.deepOrange : Colors.black87)),
                    ),
                    body: _sourceRegionExpanded && _sourceRegionWidget != null
                        ? Padding(padding: const EdgeInsets.all(16), child: _sourceRegionWidget!)
                        : const SizedBox.shrink(),
                    isExpanded: _sourceRegionExpanded,
                    canTapOnHeader: true,
                  ),
                  ExpansionPanel(
                    headerBuilder: (context, isExpanded) => ListTile(
                      leading: Icon(Icons.warning_amber_rounded, color: isPotentiallyUnstableLoad ? Colors.orange : Colors.green),
                      title: Text('Load Stability Analysis', style: TextStyle(fontWeight: FontWeight.bold, color: isPotentiallyUnstableLoad ? Colors.deepOrange : Colors.black87)),
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
    );
  }
}