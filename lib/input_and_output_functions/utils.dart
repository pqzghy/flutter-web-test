import 'dart:math';
import 'package:equations/equations.dart';

// ==========================================
// 1. 复数扩展：增加 RF 常用功能 & 阈值判断
// ==========================================
extension ComplexExt on Complex {
  /// 模值
  double get modulus => abs();

  /// 辐角 (弧度) - 修复：equations v5 中 phase 是方法，需要加 ()
  double argument() => phase();

  /// 转换为 dB 值 (20log10|S|)
  double get modulusInDb {
    double mag = modulus;
    if (mag < 1e-12) return -100.0; // 避免 log(0)
    return 20 * log(mag) / ln10;
  }

  /// 判断是否几乎为实数
  bool get isReal => imaginary.abs() < 1e-12;

  /// 判断是否几乎为纯虚数
  bool get isImaginary => real.abs() < 1e-12;

  /// 判断是否几乎为 0
  bool get isZero => abs() < 1e-12;
}

// ==========================================
// 2. 输入格式枚举
// ==========================================
enum ComplexInputFormat {
  cartesian,   // a + bj
  polarDegree, // r ∠ theta (°)
  polarRadian, // r ∠ theta (rad)
}

// ==========================================
// 3. 复数解析工具类
// ==========================================
class ComplexParser {
  static const String _sciNum = r'([+-]?\d*\.?\d+(?:[eE][+-]?\d+)?)';

  /// 字符串转复数
  static Complex parseUniversal(String input, ComplexInputFormat fmt) {
    input = input.trim().replaceAll(' ', '').replaceAll('−', '-');
    if (input.isEmpty) return Complex.zero();

    try {
      switch (fmt) {
        case ComplexInputFormat.cartesian:
          return _parseCartesian(input);
        case ComplexInputFormat.polarDegree:
          return _parsePolar(input, isDegree: true);
        case ComplexInputFormat.polarRadian:
          return _parsePolar(input, isDegree: false);
      }
    } catch (e) {
      return Complex.zero();
    }
  }

  static Complex _parseCartesian(String input) {
    if (input == 'j' || input == '+j') return const Complex(0, 1);
    if (input == '-j') return const Complex(0, -1);

    final regexStd = RegExp('^$_sciNum([+-]$_sciNum)j\$');
    if (regexStd.hasMatch(input)) {
      final m = regexStd.firstMatch(input)!;
      return Complex(double.parse(m.group(1)!), double.parse(m.group(2)!));
    }

    final regexImag = RegExp('^([+-]?)j$_sciNum\$');
    if (regexImag.hasMatch(input)) {
      final m = regexImag.firstMatch(input)!;
      final sign = m.group(1) == '-' ? -1.0 : 1.0;
      return Complex(0, sign * double.parse(m.group(2)!));
    }

    final regexImagPost = RegExp('^$_sciNum' r'j$');
    if (regexImagPost.hasMatch(input)) {
      return Complex(0, double.parse(regexImagPost.firstMatch(input)!.group(1)!));
    }

    final realVal = double.tryParse(input);
    if (realVal != null) return Complex(realVal, 0);

    return Complex.zero();
  }

  static Complex _parsePolar(String input, {required bool isDegree}) {
    final sep = input.contains('∠') ? '∠' : '<';
    if (!input.contains(sep)) return Complex.zero();

    String cleanInput = input.replaceAll('°', '').replaceAll('deg', '').replaceAll('rad', '');
    final parts = cleanInput.split(sep);
    if (parts.length != 2) return Complex.zero();

    final mag = double.tryParse(parts[0]) ?? 0.0;
    double angle = double.tryParse(parts[1]) ?? 0.0;

    if (isDegree) angle = angle * pi / 180.0;
    return Complex.fromPolar(r: mag, theta: angle);
  }
}

// ==========================================
// 4. 复数格式化工具类
// ==========================================
class ComplexFormatter {

  static String _toScientificLatex(double val, int precision) {
    if (val.abs() < 1e-12) return "0";

    String raw = val.toStringAsExponential(precision);
    if (!raw.contains('e')) return raw;

    List<String> parts = raw.split('e');
    String base = parts[0];
    int exponent = int.parse(parts[1]);

    if (base.contains('.')) {
      base = base.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }

    if (exponent == 0) return base;

    return '$base \\times 10^{$exponent}';
  }

  /// 智能数字格式化
  /// 修复：参数改为 num? 以兼容 int 和 null，防止报错
  static String smartFormat(num? val, {bool useScientific = true, int precision = 4, bool useLatex = false}) {
    if (val == null) return '';
    if (val.isNaN) return "NaN";

    // 转为 double 进行统一处理
    double d = val.toDouble();

    if (d.abs() < 1e-12) return "0";

    if ((d - d.round()).abs() < 1e-9) {
      return d.round().toString();
    }

    if (useScientific && ((d.abs() < 1e-3) || (d.abs() >= 1e5))) {
      if (useLatex) {
        return _toScientificLatex(d, precision);
      } else {
        String s = d.toStringAsExponential(precision);
        return s.replaceFirst(RegExp(r'e\+?'), 'e');
      }
    }

    String s = d.toStringAsFixed(precision);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  static String universal(Complex c, ComplexInputFormat fmt, {int precision = 4}) {
    double re = c.real.abs() < 1e-12 ? 0 : c.real;
    double im = c.imaginary.abs() < 1e-12 ? 0 : c.imaginary;

    switch (fmt) {
      case ComplexInputFormat.cartesian:
        if (im == 0) return smartFormat(re, precision: precision);
        if (re == 0) return '${smartFormat(im, precision: precision)}j';

        final sign = im < 0 ? '-' : '+';
        // 使用 abs() 避免 double 符号问题
        return '${smartFormat(re, precision: precision)}$sign${smartFormat(im.abs(), precision: precision)}j';

      case ComplexInputFormat.polarDegree:
      // 修复：phase 改为 phase()
        return '${smartFormat(c.modulus, precision: precision)}∠${smartFormat(c.phase() * 180 / pi, precision: precision)}°';

      case ComplexInputFormat.polarRadian:
      // 修复：phase 改为 phase()
        return '${smartFormat(c.modulus, precision: precision)}∠${smartFormat(c.phase(), precision: precision)}rad';
    }
  }

  static String latex(Complex c, ComplexInputFormat fmt, {int precision = 4}) {
    double re = c.real.abs() < 1e-12 ? 0 : c.real;
    double im = c.imaginary.abs() < 1e-12 ? 0 : c.imaginary;

    String fmtNum(double v) => smartFormat(v, precision: precision, useLatex: true);

    switch (fmt) {
      case ComplexInputFormat.cartesian:
        if (im == 0) return fmtNum(re);
        if (re == 0) return '${fmtNum(im)}j';

        final sign = im < 0 ? '-' : '+';
        return '${fmtNum(re)} $sign ${fmtNum(im.abs())}j';

      case ComplexInputFormat.polarDegree:
      // 修复：phase 改为 phase()
        return '${fmtNum(c.modulus)} \\angle ${fmtNum(c.phase() * 180 / pi)}^{\\circ}';

      case ComplexInputFormat.polarRadian:
      // 修复：phase 改为 phase()
        return '${fmtNum(c.modulus)} \\angle ${fmtNum(c.phase())}\\text{ rad}';
    }
  }

  static String latexHybrid(Complex c, {int precision = 4}) {
    String polar = latex(c, ComplexInputFormat.polarDegree, precision: precision);
    if (c.imaginary.abs() < 1e-12) {
      return polar;
    }
    String rect = latex(c, ComplexInputFormat.cartesian, precision: precision);
    return '$polar = $rect';
  }
}

// ==========================================
// 5. 输入辅助 (UI层)
// ==========================================
class ComplexInputUtil {
  static String joinForParse(String? real, String? imag) {
    String r = (real ?? '').trim();
    String i = (imag ?? '').trim();

    if (r.isEmpty) r = '0';
    if (i.isEmpty) i = '0';

    r = r.replaceAll(RegExp(r'[^\d\.eE\+\-]'), '');
    i = i.replaceAll(RegExp(r'[^\d\.eE\+\-]'), '');

    double rVal = double.tryParse(r) ?? 0;
    double iVal = double.tryParse(i) ?? 0;

    if (iVal == 0) return r;
    if (rVal == 0) return '${i}j';

    String sign = i.startsWith('-') ? '' : '+';
    return '$r$sign${i}j';
  }
}