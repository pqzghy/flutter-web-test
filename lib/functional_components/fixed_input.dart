import 'package:flutter/material.dart';
import '../input_and_output_functions/utils.dart';

class ComplexInputRow extends StatelessWidget {
  final ComplexInputFormat format;
  final TextEditingController ctrl1;
  final TextEditingController ctrl2;
  final String paramName;
  final String? Function(String?)? validator;

  final VoidCallback? onAnyChanged;
  final VoidCallback? onSubmit;
  final TextInputAction action1;
  final TextInputAction action2;

  const ComplexInputRow({
    required this.format,
    required this.ctrl1,
    required this.ctrl2,
    required this.paramName,
    this.validator,

    this.onAnyChanged,
    this.onSubmit,
    this.action1 = TextInputAction.next,
    this.action2 = TextInputAction.done,

    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String label1Text;
    String label2Text;
    String middleSymbol;
    String? suffix2;

    switch (format) {
      case ComplexInputFormat.cartesian:
        label1Text = "Real";
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(
              width: 42,
              child: Text(
                paramName.split(' ')[0],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // 第一个输入框
          Expanded(
            child: _buildTextField(
              controller: ctrl1,
              labelText: label1Text,
              validator: validator,
              textInputAction: action1,
              onAnyChanged: onAnyChanged,
              onSubmit: onSubmit,
            ),
          ),

          // 中间符号
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
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
              validator: validator,
              textInputAction: action2,
              onAnyChanged: onAnyChanged,
              onSubmit: onSubmit,
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
    String? Function(String?)? validator,

    TextInputAction textInputAction = TextInputAction.done,
    VoidCallback? onAnyChanged,
    VoidCallback? onSubmit,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: const TextStyle(fontSize: 16),
      textAlignVertical: TextAlignVertical.center,

      textInputAction: textInputAction,

      onChanged: (_) => onAnyChanged?.call(),

      onFieldSubmitted: (_) => onSubmit?.call(),

      onEditingComplete: () => onSubmit?.call(),

      decoration: InputDecoration(
        labelText: labelText,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        isDense: true,
        border: const OutlineInputBorder(),
        suffixText: suffix,
        suffixStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: const TextStyle(height: 0.8),
      ),
    );
  }
}
