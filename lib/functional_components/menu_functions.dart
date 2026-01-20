import 'package:flutter/material.dart';
import '../page_contents/amplifier_calculator.dart';

// 每一个页面都可以直接用 CommonScaffold 包一层，自动带标题和右上角菜单。
class CommonScaffold extends StatelessWidget {
  final String title;  // 页面顶部的标题
  final Widget body;   // 页面主体内容

  const CommonScaffold({
    required this.title,
    required this.body,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'home':
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AmplifierHomePage()),
                        (route) => false,
                  );
                  break;
                case 'gain_circle':
                  Navigator.pushReplacementNamed(context, '/gain_circle');
                  break;
                case 'gain_circle_bilateral':
                  Navigator.pushReplacementNamed(context, '/gain_circle_bilateral');
                  break;
                case 'noise_figure_circle':
                  Navigator.pushReplacementNamed(context, '/noise_figure_circle');
                  break;
                case 'blank_case':
                  Navigator.pushReplacementNamed(context, '/blank_case'); // 新增的空白菜单案例
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'home', child: Text('Main Menu')), // 主菜单
              const PopupMenuItem(value: 'gain_circle', child: Text('Constant gain circle calculation')), // 单向增益圆
              const PopupMenuItem(value: 'gain_circle_bilateral', child: Text('Bidirectional power gain circle calculation')), // 双向增益圆
              const PopupMenuItem(value: 'noise_figure_circle', child: Text('Constant Noise Figure Circle Calculation')), // 噪声圆
            ],
          )
        ],
      ),
      body: body,
    );
  }
}
