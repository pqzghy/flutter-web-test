import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:equations/equations.dart';

import '../functional_components/menu_functions.dart';
import '../input_and_output_functions/utils.dart';
import '../functional_components/fixed_input.dart';
import '../smith_chart_db_module/smith_gain_circle_painter.dart';

// ==========================================
// 主页面：只负责输入和整体调度
// ==========================================
class GainCirclePage extends StatefulWidget {
  const GainCirclePage({super.key});

  @override
  State<GainCirclePage> createState() => _GainCirclePageState();
}

class _GainCirclePageState extends State<GainCirclePage> {
  ComplexInputFormat _currentFormat = ComplexInputFormat.polarDegree;

  // 默认值 (Unilateral Case)
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

  // 传递给子模块的数据
  Complex? _s11, _s22, _s12, _s21;
  List<double>? _targetGains;

  // 【核心修复】：恢复完整的拼接逻辑，确保 ComplexParser 能正确识别格式
  String _joinInput(TextEditingController c1, TextEditingController c2) {
    String a = c1.text.trim();
    String b = c2.text.trim();
    if (a.isEmpty) a = '0';
    if (b.isEmpty) b = '0';

    switch (_currentFormat) {
      case ComplexInputFormat.cartesian:
      // 使用工具类处理 a+bj 的拼接
        return ComplexInputUtil.joinForParse(a, b);
      case ComplexInputFormat.polarDegree:
      // 显式拼接成极坐标格式，供 parser 识别
        return '$a∠$b°';
      case ComplexInputFormat.polarRadian:
        return '$a∠${b}rad';
    }
  }

  // 辅助函数：统一解析流程
  Complex _parseComplex(TextEditingController c1, TextEditingController c2) {
    String inputStr = _joinInput(c1, c2);
    return ComplexParser.parseUniversal(inputStr, _currentFormat);
  }

  // 核心功能：一键转换格式
  void switchAllFormat(ComplexInputFormat newFormat) {
    if (newFormat == _currentFormat) return;

    setState(() {
      // 定义转换函数
      void convert(TextEditingController c1, TextEditingController c2) {
        // 1. 先解析：利用 _joinInput + ComplexParser 稳健地拿到复数
        Complex c = _parseComplex(c1, c2);

        // 2. 再回填：根据新格式将复数转回字符串
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

      // 批量转换
      convert(s11C1, s11C2);
      convert(s12C1, s12C2);
      convert(s21C1, s21C2);
      convert(s22C1, s22C2);

      // 更新格式
      _currentFormat = newFormat;

      // 如果之前已经计算过，立即用新的格式刷新下方结果
      if (_hasCalculated) {
        _onCalculatePressed();
      }
    });
  }

  void _onCalculatePressed() {
    setState(() {
      // 1. 解析输入为标准复数 (a+bj)
      _s11 = _parseComplex(s11C1, s11C2);
      _s12 = _parseComplex(s12C1, s12C2);
      _s21 = _parseComplex(s21C1, s21C2);
      _s22 = _parseComplex(s22C1, s22C2);

      _targetGains = gainDbListC.text.split(',').map((e) => double.tryParse(e.trim()) ?? 0.0).toList();
      _hasCalculated = true;
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
      title: 'Unilateral Gain Circles',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 格式切换按钮
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

            // 2. 输入框
            ComplexInputRow(format: _currentFormat, ctrl1: s11C1, ctrl2: s11C2, paramName: 'S11'),
            ComplexInputRow(format: _currentFormat, ctrl1: s21C1, ctrl2: s21C2, paramName: 'S21'),
            ComplexInputRow(format: _currentFormat, ctrl1: s12C1, ctrl2: s12C2, paramName: 'S12 (Check U)'),
            ComplexInputRow(format: _currentFormat, ctrl1: s22C1, ctrl2: s22C2, paramName: 'S22'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: z0C, decoration: const InputDecoration(labelText: 'Z0 (Ω)', border: OutlineInputBorder()))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: gainDbListC, decoration: const InputDecoration(labelText: 'Target Gains (dB)', border: OutlineInputBorder()))),
            ]),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: _onCalculatePressed,
                icon: const Icon(Icons.calculate),
                label: const Text('Start Calculation', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 24),

            // 3. 结果显示区域
            if (_hasCalculated && _s11 != null) ...[
              _UnilateralFigureMeritSection(s11: _s11!, s12: _s12!, s21: _s21!, s22: _s22!, currentFormat: _currentFormat),
              const SizedBox(height: 16),

              InputGainSection(s11: _s11!, targetGains: _targetGains!, currentFormat: _currentFormat),
              const SizedBox(height: 16),

              OutputGainSection(s22: _s22!, targetGains: _targetGains!, currentFormat: _currentFormat),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 模块 1: U 因子检查 (详细教学版)
// ==========================================
class _UnilateralFigureMeritSection extends StatelessWidget {
  final Complex s11, s12, s21, s22;
  final ComplexInputFormat currentFormat;

  const _UnilateralFigureMeritSection({
    required this.s11,
    required this.s12,
    required this.s21,
    required this.s22,
    required this.currentFormat,
  });

  String _texNum(double val) => ComplexFormatter.smartFormat(val, useLatex: true);
  double toDb(double x) => (x <= 0) ? -999 : 10 * log(x) / ln10;
  Widget _texScroll(String latex) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: Math.tex(latex, textStyle: const TextStyle(fontSize: 15, color: Colors.black87)));

  @override
  Widget build(BuildContext context) {
    // 基础模值
    final s11Abs = s11.modulus;
    final s12Abs = s12.modulus;
    final s21Abs = s21.modulus;
    final s22Abs = s22.modulus;
    final s11Abs2 = pow(s11Abs, 2).toDouble();
    final s22Abs2 = pow(s22Abs, 2).toDouble();

    // U 计算
    final numU = s12Abs * s21Abs * s11Abs * s22Abs;
    final denU = (1 - s11Abs2) * (1 - s22Abs2);
    final U = (denU == 0) ? 0.0 : numU / denU;

    // 误差计算
    double errorMinDb = toDb(1 / ((1 + U) * (1 + U)));
    double errorMaxDb = toDb(1 / ((1 - U) * (1 - U)));

    final gsMax = 1 / (1 - pow(s11.modulus, 2));
    final glMax = 1 / (1 - pow(s22.modulus, 2));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("1. Unilateral Assumption Check & Max Gain", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const Divider(),

            // Step 1: 列出所有模值
            const Text("Step 1: Magnitudes of S-parameters", style: TextStyle(fontWeight: FontWeight.bold)),
            _texScroll(r'|S_{11}| = ' + _texNum(s11Abs) + r', \quad |S_{12}| = ' + _texNum(s12Abs)),
            _texScroll(r'|S_{21}| = ' + _texNum(s21Abs) + r', \quad |S_{22}| = ' + _texNum(s22Abs)),
            const SizedBox(height: 8),

            // Step 2: U 因子代入
            const Text("Step 2: Calculate U (Unilateral Figure of Merit)", style: TextStyle(fontWeight: FontWeight.bold)),
            _texScroll(r'\text{Formula: } U = \frac{|S_{12}| |S_{21}| |S_{11}| |S_{22}|}{(1-|S_{11}|^2)(1-|S_{22}|^2)}'),
            _texScroll(r'\text{Substitution: } U = \frac{' + _texNum(s12Abs) + r'\cdot' + _texNum(s21Abs) + r'\cdot' + _texNum(s11Abs) + r'\cdot' + _texNum(s22Abs) + r'}{(1-' + _texNum(s11Abs2) + r')(1-' + _texNum(s22Abs2) + r')}'),
            _texScroll(r'\text{Result: } U = ' + _texNum(U)),
            const SizedBox(height: 8),

            // Step 3: 误差判断
            const Text("Step 3: Error Analysis", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Range: ${_texNum(errorMinDb)} dB < Error < ${_texNum(errorMaxDb)} dB"),
            if (U < 0.1)
              const Text("✅ U < 0.1, unilateral assumption is VALID.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
            else
              const Text("⚠️ U > 0.1, unilateral assumption has ERROR.", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),

            const Divider(),

            // Step 4: 最大单向增益
            const Text("Maximum Gains (Assuming S12=0):", style: TextStyle(fontWeight: FontWeight.bold)),
            _texScroll(r'G_{s,max} = \frac{1}{1-|S_{11}|^2} = \frac{1}{1-' + _texNum(s11Abs2) + r'} = ' + _texNum(gsMax) + r' (' + _texNum(toDb(gsMax)) + r'\text{ dB})'),
            _texScroll(r'G_{L,max} = \frac{1}{1-|S_{22}|^2} = \frac{1}{1-' + _texNum(s22Abs2) + r'} = ' + _texNum(glMax) + r' (' + _texNum(toDb(glMax)) + r'\text{ dB})'),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 模块 2: 输入增益圆 (Input Gain Circles)
// ==========================================
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
  double toDb(double x) => (x <= 0) ? -999 : 10 * log(x) / ln10;

  // 辅助标题组件
  Widget _subHeader(String text) => Padding(padding: const EdgeInsets.only(top: 8, bottom: 2), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)));
  Widget _texScroll(String latex) => SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(vertical: 4), child: Math.tex(latex, textStyle: const TextStyle(fontSize: 15, color: Colors.black87)));

  @override
  Widget build(BuildContext context) {
    final s11Abs = widget.s11.modulus;
    final s11Abs2 = s11Abs * s11Abs;
    final gsMax = 1 / (1 - s11Abs2);

    List<GainCircleData> circles = [];
    List<List<String>> tableData = [];

    if (_expanded.length != widget.targetGains.length) {
      _expanded = List.filled(widget.targetGains.length, false);
    }

    for (int i = 0; i < widget.targetGains.length; i++) {
      double G_db = widget.targetGains[i];
      double G_lin = pow(10, G_db / 10).toDouble();

      bool exceedsMax = G_lin > gsMax * 1.0001;

      if (exceedsMax) {
        tableData.add([_texNum(G_db), "Too High", "-", "-"]);
        continue;
      }

      double g_s = G_lin / gsMax;
      double denom = 1 - s11Abs2 * (1 - g_s);
      double d_mag = (g_s * s11Abs) / denom;
      Complex d = Complex.fromPolar(r: d_mag, theta: -widget.s11.phase());
      double r = (sqrt(max(0, 1 - g_s)) * (1 - s11Abs2)) / denom;

      if (denom != 0) {
        circles.add(GainCircleData(center: d, radius: r, label: '${_texNum(G_db)}dB', color: Colors.blueAccent));
        tableData.add([
          _texNum(G_db),
          _texNum(g_s),
          ComplexFormatter.latex(d, widget.currentFormat, precision: 3),
          _texNum(r)
        ]);
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: const Text("2. Input Gain Circles (Source Plane)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
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
                  Center(child: SizedBox(height: 320, width: 320, child: SmithGainCirclePainter(gainCircles: circles, canvasSize: 320))),
                const SizedBox(height: 16),

                const Text("Summary Table:", style: TextStyle(fontWeight: FontWeight.bold)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                    columnSpacing: 20,
                    columns: const [DataColumn(label: Text('Gs(dB)')), DataColumn(label: Text('gs')), DataColumn(label: Text('Center')), DataColumn(label: Text('Radius'))],
                    rows: tableData.map((row) {
                      bool isError = row[1] == "Too High";
                      return DataRow(
                          cells: row.map((c) {
                            if (c.contains(r'\')) return DataCell(Math.tex(c, textStyle: TextStyle(color: isError ? Colors.red : Colors.black)));
                            return DataCell(Text(c, style: TextStyle(color: isError ? Colors.red : Colors.black, fontWeight: isError ? FontWeight.bold : FontWeight.normal)));
                          }).toList()
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

                    bool exceedsMax = G_lin > gsMax * 1.0001;
                    double g_s = G_lin / gsMax;
                    double denom = 1 - s11Abs2 * (1 - g_s);
                    double d_mag = (g_s * s11Abs) / denom;
                    double r_sq_inner = 1 - g_s;

                    // Center Angle display logic
                    String angleSymbol = (widget.currentFormat == ComplexInputFormat.polarDegree) ? r'^\circ' : r' \text{ rad}';
                    double angleVal = (widget.currentFormat == ComplexInputFormat.polarDegree) ? -widget.s11.phase() * 180 / pi : -widget.s11.phase();

                    return ExpansionPanel(
                      headerBuilder: (context, isExpanded) => ListTile(
                        title: Text('Circle ${index+1}: Target Gs = $G_db dB ${exceedsMax ? "(Invalid)" : ""}', style: TextStyle(fontWeight: FontWeight.bold, color: exceedsMax ? Colors.red : Colors.black)),
                      ),
                      body: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (exceedsMax) const Text("⚠️ Target Gain > Maximum Available Gain.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),

                            _subHeader("1. Normalized Gain (gs):"),
                            _texScroll(r'\text{Formula: } g_s = \frac{G_s}{G_{s,max}}'),
                            _texScroll(r'\text{Substitution: } g_s = \frac{10^{' + _texNum(G_db) + r'/10}}{' + _texNum(gsMax) + r'} = \frac{' + _texNum(G_lin) + r'}{' + _texNum(gsMax) + r'}'),
                            _texScroll(r'\text{Result: } g_s = ' + _texNum(g_s)),

                            if (!exceedsMax) ...[
                              const Divider(),
                              _subHeader("2. Center Distance (d):"),
                              _texScroll(r'\text{Formula: } d_{g_s} = \frac{g_s |S_{11}|}{1 - |S_{11}|^2 (1-g_s)}'),
                              _texScroll(r'\text{Substitution: } d_{g_s} = \frac{' + _texNum(g_s) + r' \cdot ' + _texNum(s11Abs) + r'}{1 - ' + _texNum(s11Abs2) + r'(1 - ' + _texNum(g_s) + r')}'),
                              _texScroll(r'\text{Result (Scalar): } d_{g_s} = ' + _texNum(d_mag)),
                              _texScroll(r'\text{Result (Complex): } C_{g_s} = d_{g_s} \angle S_{11}^* = ' + _texNum(d_mag) + r' \angle ' + _texNum(angleVal) + angleSymbol),

                              const Divider(),
                              _subHeader("3. Radius (r):"),
                              _texScroll(r'\text{Formula: } r_{g_s} = \frac{\sqrt{1-g_s}(1-|S_{11}|^2)}{1 - |S_{11}|^2 (1-g_s)}'),
                              _texScroll(r'\text{Substitution: } r_{g_s} = \frac{\sqrt{1-' + _texNum(g_s) + r'}(1-' + _texNum(s11Abs2) + r')}{' + _texNum(denom) + r'}'),
                              _texScroll(r'\text{Result: } r_{g_s} = ' + _texNum( (sqrt(max(0,r_sq_inner)) * (1 - s11Abs2)) / denom )),
                            ]
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

// ==========================================
// 模块 3: 输出增益圆 (Output Gain Circles)
// ==========================================
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
  double toDb(double x) => (x <= 0) ? -999 : 10 * log(x) / ln10;
  Widget _texScroll(String latex) => SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(vertical: 4), child: Math.tex(latex, textStyle: const TextStyle(fontSize: 15, color: Colors.black87)));
  Widget _subHeader(String text) => Padding(padding: const EdgeInsets.only(top: 8, bottom: 2), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)));

  @override
  Widget build(BuildContext context) {
    final s22Abs = widget.s22.modulus;
    final s22Abs2 = s22Abs * s22Abs;
    final glMax = 1 / (1 - s22Abs2);

    List<GainCircleData> circles = [];
    List<List<String>> tableData = [];

    if (_expanded.length != widget.targetGains.length) {
      _expanded = List.filled(widget.targetGains.length, false);
    }

    for (int i = 0; i < widget.targetGains.length; i++) {
      double G_db = widget.targetGains[i];
      double G_lin = pow(10, G_db / 10).toDouble();

      bool exceedsMax = G_lin > glMax * 1.0001;

      if (exceedsMax) {
        tableData.add([_texNum(G_db), "Too High", "-", "-"]);
        continue;
      }

      double g_l = G_lin / glMax;
      double denom = 1 - s22Abs2 * (1 - g_l);
      double d_mag = (g_l * s22Abs) / denom;
      Complex d = Complex.fromPolar(r: d_mag, theta: -widget.s22.phase());
      double r = (sqrt(max(0, 1 - g_l)) * (1 - s22Abs2)) / denom;

      if (denom != 0) {
        circles.add(GainCircleData(center: d, radius: r, label: '${_texNum(G_db)}dB', color: Colors.redAccent));
        tableData.add([
          _texNum(G_db),
          _texNum(g_l),
          ComplexFormatter.latex(d, widget.currentFormat, precision: 3),
          _texNum(r)
        ]);
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: const Text("3. Output Gain Circles (Load Plane)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
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
                  Center(child: SizedBox(height: 320, width: 320, child: SmithGainCirclePainter(gainCircles: circles, canvasSize: 320))),
                const SizedBox(height: 16),

                const Text("Summary Table:", style: TextStyle(fontWeight: FontWeight.bold)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                    columnSpacing: 20,
                    columns: const [DataColumn(label: Text('GL(dB)')), DataColumn(label: Text('gL')), DataColumn(label: Text('Center')), DataColumn(label: Text('Radius'))],
                    rows: tableData.map((row) {
                      bool isError = row[1] == "Too High";
                      return DataRow(
                          cells: row.map((c) {
                            if (c.contains(r'\')) return DataCell(Math.tex(c, textStyle: TextStyle(color: isError ? Colors.red : Colors.black)));
                            return DataCell(Text(c, style: TextStyle(color: isError ? Colors.red : Colors.black, fontWeight: isError ? FontWeight.bold : FontWeight.normal)));
                          }).toList()
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
                    bool exceedsMax = G_lin > glMax * 1.0001;
                    double g_l = G_lin / glMax;
                    double denom = 1 - s22Abs2 * (1 - g_l);
                    double d_mag = (g_l * s22Abs) / denom;
                    double r_sq_inner = 1 - g_l;

                    String angleSymbol = (widget.currentFormat == ComplexInputFormat.polarDegree) ? r'^\circ' : r' \text{ rad}';
                    double angleVal = (widget.currentFormat == ComplexInputFormat.polarDegree) ? -widget.s22.phase() * 180 / pi : -widget.s22.phase();

                    return ExpansionPanel(
                      headerBuilder: (context, isExpanded) => ListTile(
                        title: Text('Circle ${index+1}: Target GL = $G_db dB ${exceedsMax ? "(Invalid)" : ""}', style: TextStyle(fontWeight: FontWeight.bold, color: exceedsMax ? Colors.red : Colors.black)),
                      ),
                      body: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (exceedsMax) const Text("⚠️ Target Gain > Maximum Available Gain.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),

                            _subHeader("1. Normalized Gain (gL):"),
                            _texScroll(r'\text{Formula: } g_L = \frac{G_L}{G_{L,max}}'),
                            _texScroll(r'\text{Substitution: } g_L = \frac{10^{' + _texNum(G_db) + r'/10}}{' + _texNum(glMax) + r'} = \frac{' + _texNum(G_lin) + r'}{' + _texNum(glMax) + r'}'),
                            _texScroll(r'\text{Result: } g_L = ' + _texNum(g_l)),

                            if (!exceedsMax) ...[
                              const Divider(),
                              _subHeader("2. Center Distance (d):"),
                              _texScroll(r'\text{Formula: } d_{g_L} = \frac{g_L |S_{22}|}{1 - |S_{22}|^2 (1-g_L)}'),
                              _texScroll(r'\text{Substitution: } d_{g_L} = \frac{' + _texNum(g_l) + r' \cdot ' + _texNum(s22Abs) + r'}{1 - ' + _texNum(s22Abs2) + r'(1 - ' + _texNum(g_l) + r')}'),
                              _texScroll(r'\text{Result (Scalar): } d_{g_L} = ' + _texNum(d_mag)),
                              _texScroll(r'\text{Result (Complex): } C_{g_L} = d_{g_L} \angle S_{22}^* = ' + _texNum(d_mag) + r' \angle ' + _texNum(angleVal) + angleSymbol),

                              const Divider(),
                              _subHeader("3. Radius (r):"),
                              _texScroll(r'\text{Formula: } r_{g_L} = \frac{\sqrt{1-g_L}(1-|S_{22}|^2)}{1 - |S_{22}|^2 (1-g_L)}'),
                              _texScroll(r'\text{Substitution: } r_{g_L} = \frac{\sqrt{1-' + _texNum(g_l) + r'}(1-' + _texNum(s22Abs2) + r')}{' + _texNum(denom) + r'}'),
                              _texScroll(r'\text{Result: } r_{g_L} = ' + _texNum( (sqrt(max(0,r_sq_inner)) * (1 - s22Abs2)) / denom )),
                            ]
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