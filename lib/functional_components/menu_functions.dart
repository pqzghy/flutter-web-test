import 'package:flutter/material.dart';
import '../page_contents/amplifier_calculator.dart';

class CommonScaffold extends StatelessWidget {
  final String title;
  final Widget body;

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
                  Navigator.pushReplacementNamed(context, '/blank_case');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'home', child: Text('Main Menu')), // 主菜单
              const PopupMenuItem(value: 'gain_circle', child: Text('Unidirectional gain circle')), // 单向增益圆
              const PopupMenuItem(value: 'gain_circle_bilateral', child: Text('Bidirectional gain circle')), // 双向增益圆
              const PopupMenuItem(value: 'noise_figure_circle', child: Text('Noise circle calculation')), // 噪声圆
            ],
          )
        ],
      ),
      body: body,
    );
  }
}
