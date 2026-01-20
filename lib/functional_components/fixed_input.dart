import 'package:flutter/material.dart';
import '../input_and_output_functions/utils.dart';

class ComplexInputRow extends StatelessWidget {
  final ComplexInputFormat format;
  final TextEditingController ctrl1;
  final TextEditingController ctrl2;
  final String paramName;

  const ComplexInputRow({
    required this.format,
    required this.ctrl1,
    required this.ctrl2,
    required this.paramName,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1. 根据格式定义显示的文案和符号
    String label1Text;
    String label2Text;
    String middleSymbol;
    String? suffix2;

    switch (format) {
      case ComplexInputFormat.cartesian:
        label1Text = "Real"; // 简化文案，留出更多空间给数字
        label2Text = "Imag";
        middleSymbol = "+";
        suffix2 = "j";
        break;
      case ComplexInputFormat.polarDegree:
        label1Text = "Mag";
        label2Text = "Ang";
        middleSymbol = "∠";
        suffix2 = "°";
        break;
      case ComplexInputFormat.polarRadian:
        label1Text = "Mag";
        label2Text = "Rad";
        middleSymbol = "∠";
        suffix2 = "rad";
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8), // 增加垂直间距，让行与行之间不那么挤
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 参数名 (S11 等) - 加宽一点，防止 S12 (Check U) 这种换行
          SizedBox(
            width: 42,
            child: Text(
              paramName.split(' ')[0], // 只取 S11/S12 等前缀，避免太长
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          // 第一个输入框
          Expanded(
            child: _buildTextField(
              controller: ctrl1,
              labelText: label1Text,
            ),
          ),

          // 中间符号
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              middleSymbol,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),

          // 第二个输入框
          Expanded(
            child: _buildTextField(
              controller: ctrl2,
              labelText: label2Text,
              suffix: suffix2,
            ),
          ),
        ],
      ),
    );
  }

  // 封装输入框构建逻辑
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      // 弹出带小数点的数字键盘
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      // 【改动点】字体变大
      style: const TextStyle(fontSize: 16),
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        labelText: labelText,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        // 【改动点】增加内边距，让框变高、变大
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        isDense: true,
        border: const OutlineInputBorder(),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }
}