import 'dart:math';
import 'package:flutter/material.dart';
import 'package:equations/equations.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../functional_components/menu_functions.dart';
import '../input_and_output_functions/utils.dart';
import '../functional_components/fixed_input.dart';
import '../smith_chart_db_module/smith_gain_circle_painter.dart';

// 简单的数据结构，用于存储 Panel 内容
class StepPanel {
  final String title;
  final List<Widget> content;
  StepPanel({required this.title, required this.content});
}

class GainCircleBilateralPage extends StatefulWidget {
  const GainCircleBilateralPage({super.key});

  @override
  State<GainCircleBilateralPage> createState() => _GainCircleBilateralPageState();
}

class _GainCircleBilateralPageState extends State<GainCircleBilateralPage> {
  ComplexInputFormat _currentFormat = ComplexInputFormat.polarDegree;

  // 默认值设为 Pozar 例题数据 (S21 大, S12 小)
  final s11C1 = TextEditingController(text: '0.26');
  final s11C2 = TextEditingController(text: '-55');
  final s12C1 = TextEditingController(text: '0.08');
  final s12C2 = TextEditingController(text: '80');
  final s21C1 = TextEditingController(text: '2.14');
  final s21C2 = TextEditingController(text: '65');
  final s22C1 = TextEditingController(text: '0.82');
  final s22C2 = TextEditingController(text: '-30');
  final z0C = TextEditingController(text: '50');
  final gainDbListC = TextEditingController(text: '6, 8, 10');

  bool _hasCalculated = false;

  // 详细步骤面板数据
  List<bool> _expandedList = [];
  List<StepPanel> _stepPanels = [];

  // 【新增】表格汇总数据
  List<List<String>> _summaryTableData = [];

  // 史密斯图绘制数据
  List<GainCircleData> gainCirclesData = [];

  // 稳定性状态
  bool _isUnconditionallyStable = false;

  // 辅助：输入拼接
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

      _currentFormat = newFormat;
      if (_hasCalculated) _onCalculatePressed();
    });
  }

  // ⚡️ 核心工具：强制生成 LaTeX 格式的数字字符串
  String _texNum(double val) {
    return ComplexFormatter.smartFormat(val, useLatex: true);
  }

  // UI Helpers
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

  void _onCalculatePressed() {
    setState(() {
      _hasCalculated = true;
      _stepPanels.clear();
      gainCirclesData.clear();
      _summaryTableData.clear(); // 清空旧表格数据

      // 1. 解析输入
      final S11 = ComplexParser.parseUniversal(_joinInput(s11C1, s11C2), _currentFormat);
      final S12 = ComplexParser.parseUniversal(_joinInput(s12C1, s12C2), _currentFormat);
      final S21 = ComplexParser.parseUniversal(_joinInput(s21C1, s21C2), _currentFormat);
      final S22 = ComplexParser.parseUniversal(_joinInput(s22C1, s22C2), _currentFormat);

      // 2. 计算基础参数
      final S11abs = S11.modulus, S11abs2 = S11abs * S11abs;
      final S12abs = S12.modulus;
      final S21abs = S21.modulus, S21abs2 = S21abs * S21abs;
      final S22abs = S22.modulus, S22abs2 = S22abs * S22abs;
      final delta = S11 * S22 - S12 * S21;
      final deltaAbs = delta.modulus, deltaAbs2 = deltaAbs * deltaAbs;

      // K 因子
      final K = (1 + deltaAbs2 - S11abs2 - S22abs2) / (2 * S12abs * S21abs);

      // 判定分支条件
      _isUnconditionallyStable = (K > 1 && deltaAbs < 1);

      // 3. 构建 "Stability Check" 面板 (带代入)
      _stepPanels.add(
        StepPanel(
          title: '1. Stability Check (K, Δ)',
          content: [
            _text('Formula:', bold: true),
            _texScroll(r'K = \frac{1 - |S_{11}|^2 - |S_{22}|^2 + |\Delta|^2}{2|S_{12}||S_{21}|}'),
            _text('Substitution:', bold: true),
            _texScroll(
                r'K = \frac{1 - ' + _texNum(S11abs2) + r' - ' + _texNum(S22abs2) + r' + ' + _texNum(deltaAbs2) + r'}' +
                    r'{2 \cdot |' + _texNum(S12abs) + r'| \cdot |' + _texNum(S21abs) + r'|}'
            ),
            _text('Result:', bold: true),
            _texScroll(r'K = ' + _texNum(K)),
            _texScroll(r'|\Delta| = ' + _texNum(deltaAbs)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isUnconditionallyStable ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _isUnconditionallyStable ? Colors.green : Colors.deepOrange),
              ),
              child: Text(
                _isUnconditionallyStable
                    ? "✅ Unconditionally Stable (K > 1, |Δ| < 1)"
                    : "⚠️ Potentially Unstable (K < 1 or |Δ| > 1)",
                style: TextStyle(
                  color: _isUnconditionallyStable ? Colors.green[800] : Colors.deepOrange[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      // 4. 计算 MAG / MSG
      double? Gp_max, Gp_max_dB;
      final MSG = (S12abs == 0) ? 0.0 : S21abs / S12abs; // 防除零
      final MSG_dB = (MSG == 0) ? 0.0 : 10 * log(MSG) / ln10;

      if (K > 1) {
        final term = (K - sqrt(K * K - 1));
        Gp_max = MSG * term;
        Gp_max_dB = 10 * log(Gp_max) / ln10;

        _stepPanels.add(
          StepPanel(
            title: '2. Maximum Operating Power Gain (MAG)',
            content: [
              _text('Formula:', bold: true),
              _texScroll(r'G_{p,\max} = \frac{|S_{21}|}{|S_{12}|} (K - \sqrt{K^2 - 1})'),
              _text('Substitution:', bold: true),
              _texScroll(
                  r'G_{p,\max} = \frac{' + _texNum(S21abs) + r'}{' + _texNum(S12abs) + r'} (' + _texNum(K) + r' - \sqrt{' + _texNum(K) + r'^2 - 1})'
              ),
              _text('Result:', bold: true),
              _texScroll(r'MAG = ' + _texNum(Gp_max) + r' \quad (' + _texNum(Gp_max_dB) + r' \text{ dB})'),
            ],
          ),
        );
      } else {
        _stepPanels.add(
          StepPanel(
            title: '2. Maximum Stable Gain (MSG)',
            content: [
              _text('Since device is potentially unstable, MAG is undefined. Use MSG:', bold: true),
              _texScroll(r'MSG = \frac{|S_{21}|}{|S_{12}|}'),
              _text('Substitution:', bold: true),
              _texScroll(r'MSG = \frac{' + _texNum(S21abs) + r'}{' + _texNum(S12abs) + r'}'),
              _text('Result:', bold: true),
              _texScroll(r'MSG = ' + _texNum(MSG) + r' \quad (' + _texNum(MSG_dB) + r' \text{ dB})'),
            ],
          ),
        );
      }

      // 5. 计算增益圆
      final dbList = gainDbListC.text.split(',').map((e) => double.tryParse(e.trim())).whereType<double>().toList();

      // 辅助变量 C2 用于计算圆心 (公式: Cp = gp * C2* / (1 + gp(...)))
      final C2 = S22 - delta * S11.conjugate();

      // 构建 "Operating Power Gain Circles" 面板内容
      List<Widget> circleWidgets = [];

      // 5.1 显示通用公式
      circleWidgets.add(_text('General Formulas:', bold: true));
      circleWidgets.add(_texScroll(r'g_p = \frac{10^{G_{dB}/10}}{|S_{21}|^2}'));
      circleWidgets.add(_texScroll(r'C_p = \frac{g_p C_2^*}{1 + g_p(|S_{22}|^2 - |\Delta|^2)}, \quad r_p = \frac{\sqrt{1 - 2K|S_{12}S_{21}|g_p + |S_{12}S_{21}|^2 g_p^2}}{|1 + g_p(|S_{22}|^2 - |\Delta|^2)|}'));
      circleWidgets.add(_text('Where intermediate constant C2 is:', bold: true));
      circleWidgets.add(_texScroll(r'C_2 = S_{22} - \Delta S_{11}^* = ' + ComplexFormatter.latexHybrid(C2, precision: 3)));

      for (int i = 0; i < dbList.length; i++) {
        final currentGpDB = dbList[i];

        // 检查是否超过最大增益 (仅在稳定时检查)
        if (_isUnconditionallyStable && Gp_max_dB != null && currentGpDB > Gp_max_dB) {
          circleWidgets.add(const Divider());
          circleWidgets.add(
              Text('⚠️ Target gain (${currentGpDB} dB) > MAG (${ComplexFormatter.smartFormat(Gp_max_dB)} dB). Circle not physical.',
                  style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic))
          );
          // 也要在表格里加一行错误的记录吗？不用，直接跳过
          continue;
        }

        final currentGpLin = pow(10, currentGpDB / 10).toDouble();
        final gp = currentGpLin / S21abs2;

        final denominatorCp = 1 + gp * (S22abs2 - deltaAbs2);
        final Cp = C2.conjugate() * Complex(gp, 0) / Complex(denominatorCp, 0);

        final S12S21abs = S12abs * S21abs;
        final numerator_rp_val = 1 - 2 * K * S12S21abs * gp + pow(S12S21abs, 2) * gp * gp;

        double rp = 0;
        if (numerator_rp_val >= 0) {
          rp = sqrt(numerator_rp_val) / denominatorCp.abs();
        } else {
          rp = 0; // 保护
        }

        // A. 添加到绘图数据
        gainCirclesData.add(GainCircleData(
          center: Cp,
          radius: rp,
          label: '${ComplexFormatter.smartFormat(currentGpDB)}dB',
          color: _isUnconditionallyStable ? Colors.green : Colors.orange,
        ));

        // B. 【关键】添加到汇总表格数据
        _summaryTableData.add([
          ComplexFormatter.smartFormat(currentGpDB),
          ComplexFormatter.smartFormat(gp, precision: 4),
          ComplexFormatter.universal(Cp, _currentFormat, precision: 3),
          ComplexFormatter.smartFormat(rp, precision: 4),
        ]);

        // C. 添加详细文本描述
        circleWidgets.add(const Divider());
        circleWidgets.add(_text('Circle ${i+1}: Target Gain = ${ComplexFormatter.smartFormat(currentGpDB)} dB', bold: true));

        // 仅对第一个圆展示极其详细的代入过程
        if (i == 0) {
          circleWidgets.add(_text('Step 1: Normalize Gain (gp)', bold: true));
          circleWidgets.add(_texScroll(r'g_p = \frac{10^{(' + _texNum(currentGpDB) + r'/10)}}{|' + _texNum(S21abs) + r'|^2} = \frac{' + _texNum(currentGpLin) + r'}{' + _texNum(S21abs2) + r'} = ' + _texNum(gp)));

          circleWidgets.add(_text('Step 2: Calculate Center (Cp)', bold: true));
          circleWidgets.add(_texScroll(r'\text{Denom} = 1 + ' + _texNum(gp) + r'(|' + _texNum(S22abs) + r'|^2 - |' + _texNum(deltaAbs) + r'|^2) = ' + _texNum(denominatorCp)));
          circleWidgets.add(_texScroll(r'C_p = \frac{' + _texNum(gp) + r' \cdot (' + ComplexFormatter.latex(C2.conjugate(), _currentFormat, precision: 2) + r')}{' + _texNum(denominatorCp) + r'}'));
          circleWidgets.add(_texScroll(r'C_p = ' + ComplexFormatter.latexHybrid(Cp, precision: 3)));

          circleWidgets.add(_text('Step 3: Calculate Radius (rp)', bold: true));
          circleWidgets.add(_texScroll(r'r_p = \frac{\sqrt{1 - 2(' + _texNum(K) + r')|S_{12}S_{21}|(' + _texNum(gp) + r') + |S_{12}S_{21}|^2 (' + _texNum(gp) + r')^2}}{' + _texNum(denominatorCp) + r'}'));
          circleWidgets.add(_texScroll(r'r_p = ' + _texNum(rp)));
        } else {
          circleWidgets.add(_texScroll(r'g_p = ' + _texNum(gp) + r', \quad C_p = ' + ComplexFormatter.latexHybrid(Cp, precision: 3) + r', \quad r_p = ' + _texNum(rp)));
        }
      }

      _stepPanels.add(
        StepPanel(
          title: '3. Operating Power Gain Circles',
          content: circleWidgets,
        ),
      );

      // 6. 共轭匹配 (仅稳定时)
      if (_isUnconditionallyStable) {
        final B1 = 1 + S11abs2 - S22abs2 - deltaAbs2;
        final B2 = 1 + S22abs2 - S11abs2 - deltaAbs2;
        final C1 = S11 - delta * S22.conjugate();

        // Γms
        double discrim1 = B1 * B1 - 4 * C1.modulus * C1.modulus;
        Complex twoC1 = C1 * Complex(2, 0);

        // Γml
        double discrim2 = B2 * B2 - 4 * C2.modulus * C2.modulus;
        Complex twoC2 = C2 * Complex(2, 0);

        if (discrim1 >= 0 && discrim2 >= 0 && twoC1.modulus > 1e-9) {
          Complex Gms_calc = Complex(B1 - sqrt(discrim1), 0) / twoC1;
          if (Gms_calc.modulus > 1) {
            Gms_calc = Complex(B1 + sqrt(discrim1), 0) / twoC1;
          }

          Complex Gml_calc = Complex(B2 - sqrt(discrim2), 0) / twoC2;
          if (Gml_calc.modulus > 1) {
            Gml_calc = Complex(B2 + sqrt(discrim2), 0) / twoC2;
          }

          _stepPanels.add(
            StepPanel(
              title: '4. Simultaneous Conjugate Match',
              content: [
                _text('Since K>1, calculate simultaneous matching points:', bold: true),
                _text('Formulas:', bold: true),
                _texScroll(r'\Gamma_{Ms} = \frac{B_1 \pm \sqrt{B_1^2 - 4|C_1|^2}}{2C_1}, \quad \Gamma_{ML} = \frac{B_2 \pm \sqrt{B_2^2 - 4|C_2|^2}}{2C_2}'),
                _text('Results:', bold: true),
                _texScroll(r'\Gamma_{Ms} = ' + ComplexFormatter.latexHybrid(Gms_calc, precision: 3)),
                _texScroll(r'\Gamma_{ML} = ' + ComplexFormatter.latexHybrid(Gml_calc, precision: 3)),
              ],
            ),
          );
        }
      } else {
        _stepPanels.add(
          StepPanel(
            title: '4. Conjugate Match Analysis',
            content: [
              _text('Note: Simultaneous conjugate match is not possible for potentially unstable devices.', bold: true),
            ],
          ),
        );
      }

      // 初始化折叠状态
      if (_expandedList.length != _stepPanels.length) {
        _expandedList = List.generate(_stepPanels.length, (index) => false); // 默认全展开
      }
    });
  }

  // 表格构建器
  Widget _buildSummaryTable() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Circles Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
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
      title: 'Bilateral Gain Circles',
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

            ComplexInputRow(format: _currentFormat, ctrl1: s11C1, ctrl2: s11C2, paramName: 'S11'),
            ComplexInputRow(format: _currentFormat, ctrl1: s12C1, ctrl2: s12C2, paramName: 'S12'),
            ComplexInputRow(format: _currentFormat, ctrl1: s21C1, ctrl2: s21C2, paramName: 'S21'),
            ComplexInputRow(format: _currentFormat, ctrl1: s22C1, ctrl2: s22C2, paramName: 'S22'),

            const SizedBox(height: 12),
            TextField(controller: z0C, decoration: const InputDecoration(labelText: 'Z0 (Ohm)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: gainDbListC, decoration: const InputDecoration(labelText: 'Target Gains (dB, comma separated)', border: OutlineInputBorder())),

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
              // 1. 史密斯图可视化
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
                      const Text("Smith Chart Visualization", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple)),
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

              // 2. 结果汇总表格
              if (_summaryTableData.isNotEmpty) _buildSummaryTable(),

              const SizedBox(height: 20),
              const Text("Detailed Derivation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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