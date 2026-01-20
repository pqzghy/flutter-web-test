import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'dart:math';
import 'package:equations/equations.dart';

import '../functional_components/menu_functions.dart';
import '../input_and_output_functions/utils.dart';
import '../functional_components/fixed_input.dart';
import '../smith_chart_db_module/smith_gain_circle_painter.dart';

class ConstantNoiseFigureCirclesPage extends StatefulWidget {
  const ConstantNoiseFigureCirclesPage({super.key});

  @override
  State<ConstantNoiseFigureCirclesPage> createState() => _ConstantNoiseFigureCirclesPageState();
}

class _ConstantNoiseFigureCirclesPageState extends State<ConstantNoiseFigureCirclesPage> {
  ComplexInputFormat _currentFormat = ComplexInputFormat.polarDegree;

  // 默认值 (Pozar Example 11.4)
  final s11C1 = TextEditingController(text: '0.6');
  final s11C2 = TextEditingController(text: '-60');
  final s12C1 = TextEditingController(text: '0.05');
  final s12C2 = TextEditingController(text: '26');
  final s21C1 = TextEditingController(text: '1.9');
  final s21C2 = TextEditingController(text: '81');
  final s22C1 = TextEditingController(text: '0.5');
  final s22C2 = TextEditingController(text: '-60');

  // 噪声参数
  final gammaOptC1 = TextEditingController(text: '0.485');
  final gammaOptC2 = TextEditingController(text: '155');
  final z0C = TextEditingController(text: '50');
  final fminC = TextEditingController(text: '2');
  final rnC = TextEditingController(text: '4');
  final fListC = TextEditingController(text: '2.5, 3.0, 3.5, 4.0, 5.0');

  bool _hasCalculated = false;

  // 详细步骤数据
  List<bool> _expandedList = [];
  List<StepPanel> _stepPanels = [];

  // 表格汇总数据
  List<List<String>> _summaryTableData = [];

  // 史密斯图绘制数据
  List<GainCircleData> noiseFigureCirclePainterData = [];

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
      void convert(TextEditingController c1, TextEditingController c2) {
        final c = ComplexParser.parseUniversal(_joinInput(c1, c2), _currentFormat);
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

      convert(s11C1, s11C2);
      convert(s12C1, s12C2);
      convert(s21C1, s21C2);
      convert(s22C1, s22C2);
      convert(gammaOptC1, gammaOptC2);

      _currentFormat = newFormat;
      if (_hasCalculated) _onCalculatePressed();
    });
  }

  void _onCalculatePressed() {
    setState(() {
      _hasCalculated = true;
      _calculateNoiseFigureResults();
    });
  }

  void _calculateNoiseFigureResults() {
    final Gamma_opt = ComplexParser.parseUniversal(_joinInput(gammaOptC1, gammaOptC2), _currentFormat);
    final Z0 = double.tryParse(z0C.text) ?? 50.0;
    final Fmin_dB = double.tryParse(fminC.text) ?? 0.0;
    final Fmin_lin = pow(10, Fmin_dB / 10).toDouble();
    final Rn_val = double.tryParse(rnC.text) ?? 0.0;
    final rn = Rn_val / Z0;

    final gammaOptAbs = Gamma_opt.modulus;
    final gammaOptAbs2 = gammaOptAbs * gammaOptAbs;
    final onePlusGammaOptAbs2 = pow((Complex(1, 0) + Gamma_opt).modulus, 2).toDouble();

    final fListDb = fListC.text.split(',').map((e) => double.tryParse(e.trim())).whereType<double>().toList();

    // 清空旧数据
    noiseFigureCirclePainterData.clear();
    _stepPanels.clear();
    _summaryTableData.clear();

    // 1. 添加基础公式面板
    _stepPanels.add(
      StepPanel(
        title: 'Basic Formulas & Parameters',
        content: [
          _text('Noise Figure Formula:', bold: true),
          _texScroll(r'F = F_{\min} + \frac{4 r_n |\Gamma_s - \Gamma_{opt}|^2}{ (1 - |\Gamma_s|^2) |1 + \Gamma_{opt}|^2 }'),
          _text('Given Parameters:', bold: true),
          _texScroll(r'Z_0 = ' + ComplexFormatter.smartFormat(Z0) + r' \Omega'),
          _texScroll(r'R_n = ' + ComplexFormatter.smartFormat(Rn_val) + r' \Omega \Rightarrow r_n = \frac{R_n}{Z_0} = ' + ComplexFormatter.smartFormat(rn)),
          _texScroll(r'F_{\min} = ' + ComplexFormatter.smartFormat(Fmin_dB) + r' \text{ dB}'),
          _texScroll(r'\Gamma_{opt} = ' + ComplexFormatter.latexHybrid(Gamma_opt, precision: 4)),
        ],
      ),
    );

    // 2. 循环计算
    for (int i = 0; i < fListDb.length; i++) {
      final Fi_db = fListDb[i];
      final Fi_lin = pow(10, Fi_db / 10).toDouble();

      // 参数 N
      final Ni = (Fi_lin - Fmin_lin) / (4 * rn) * onePlusGammaOptAbs2;

      // 圆心 C
      final CFi = Gamma_opt / Complex(1 + Ni, 0);

      // 半径 R
      final numerator = Ni * Ni + Ni * (1 - gammaOptAbs2);
      final rFi = numerator >= 0 ? sqrt(numerator) / (1 + Ni) : 0.0;

      // A. 添加到史密斯图数据源
      noiseFigureCirclePainterData.add(
        GainCircleData(
          center: CFi,
          radius: rFi,
          color: Colors.blueAccent,
          label: '${ComplexFormatter.smartFormat(Fi_db)}dB',
        ),
      );

      // B. 添加到表格汇总数据源
      _summaryTableData.add([
        ComplexFormatter.smartFormat(Fi_db),
        ComplexFormatter.smartFormat(Ni, precision: 4),
        ComplexFormatter.universal(CFi, _currentFormat, precision: 3),
        ComplexFormatter.smartFormat(rFi, precision: 4),
      ]);

      // C. 添加详细步骤面板 (带代入过程)
      _stepPanels.add(
        StepPanel(
          title: 'Target F = ${ComplexFormatter.smartFormat(Fi_db)} dB',
          content: [
            _text('1. Convert F to linear:', bold: true),
            _texScroll(r'F = 10^{(' + ComplexFormatter.smartFormat(Fi_db) + r'/10)} = ' + ComplexFormatter.smartFormat(Fi_lin)),

            _text('2. Calculate Parameter Ni:', bold: true),
            _texScroll(r'\text{Formula: } N_i = \frac{F - F_{\min}}{4 r_n} |1 + \Gamma_{opt}|^2'),
            _text('Substitution:', bold: true),
            // 详细代入过程
            _texScroll(
                r'N_i = \frac{' + ComplexFormatter.smartFormat(Fi_lin) + r' - ' + ComplexFormatter.smartFormat(Fmin_lin) + r'}' +
                    r'{4 \cdot ' + ComplexFormatter.smartFormat(rn) + r'} \cdot |1 + ' + ComplexFormatter.latex(Gamma_opt, _currentFormat) + r'|^2'
            ),
            _text('Result:', bold: true),
            _texScroll(r'N_i = ' + ComplexFormatter.smartFormat(Ni)),

            const Divider(),

            _text('3. Circle Center (C) & Radius (R):', bold: true),
            _texScroll(r'\text{Formula: } C_{Fi} = \frac{\Gamma_{opt}}{1 + N_i}'),
            _text('Substitution:', bold: true),
            _texScroll(
                r'C_{Fi} = \frac{' + ComplexFormatter.latex(Gamma_opt, _currentFormat) + r'}{1 + ' + ComplexFormatter.smartFormat(Ni) + r'}'
            ),
            _text('Result:', bold: true),
            _texScroll(r'C_{Fi} = ' + ComplexFormatter.latexHybrid(CFi, precision: 4)),

            const SizedBox(height: 8),
            _texScroll(r'\text{Formula: } R_{Fi} = \frac{\sqrt{N_i^2 + N_i(1 - |\Gamma_{opt}|^2)}}{1 + N_i}'),
            _text('Substitution:', bold: true),
            _texScroll(
                r'R_{Fi} = \frac{\sqrt{' + ComplexFormatter.smartFormat(Ni) + r'^2 + ' + ComplexFormatter.smartFormat(Ni) + r'(1 - |' + ComplexFormatter.smartFormat(Gamma_opt.modulus) + r'|^2)}}{1 + ' + ComplexFormatter.smartFormat(Ni) + r'}'
            ),
            _text('Result:', bold: true),
            _texScroll(r'R_{Fi} = ' + ComplexFormatter.smartFormat(rFi)),
          ],
        ),
      );
    }

    if (_expandedList.length != _stepPanels.length) {
      _expandedList = List.generate(_stepPanels.length, (index) => false);
    }
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
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }

  // 构建汇总表格
  Widget _buildSummaryTable() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Results Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                columns: const [
                  DataColumn(label: Text('F (dB)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Parameter Ni', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Center (C)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Radius (R)', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _summaryTableData.map((row) {
                  return DataRow(cells: [
                    DataCell(Text(row[0], style: const TextStyle(fontWeight: FontWeight.bold))),
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

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: 'Constant Noise Figure Circles',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            // 输入区域
            const Text('Noise Parameters:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ComplexInputRow(format: _currentFormat, ctrl1: gammaOptC1, ctrl2: gammaOptC2, paramName: 'Γopt'),
            Row(
              children: [
                Expanded(child: TextField(controller: fminC, decoration: const InputDecoration(labelText: 'Fmin (dB)', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: rnC, decoration: const InputDecoration(labelText: 'Rn (Ω)', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: z0C, decoration: const InputDecoration(labelText: 'Z0 (Ω)', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: fListC, decoration: const InputDecoration(labelText: 'Target F (dB)', border: OutlineInputBorder()))),
              ],
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _onCalculatePressed,
                icon: const Icon(Icons.calculate),
                label: const Text('Calculate Noise Circles', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (_hasCalculated) ...[
              // 1. 史密斯图可视化 (最显眼)
              if (noiseFigureCirclePainterData.isNotEmpty)
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
                      const Text("Visualization", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple)),
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

              // 2. 结果汇总表格
              if (_summaryTableData.isNotEmpty)
                _buildSummaryTable(),

              const SizedBox(height: 20),
              const Text("Detailed Derivation (Teaching Mode)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),

              // 3. 详细步骤面板
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
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class StepPanel {
  final String title;
  final List<Widget> content;
  StepPanel({required this.title, required this.content});
}