import 'package:flutter/material.dart';
import 'page_contents/amplifier_calculator.dart';
import 'page_contents/gain_circle_page.dart';
import 'page_contents/gain_circle_bilateral_page.dart';
import 'page_contents/constant_noise_figure_circles.dart';

void main() => runApp(const AmplifierApp());

class AmplifierApp extends StatelessWidget {
  const AmplifierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Amplifier Full Flow Calculator',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      initialRoute: '/',
      routes: {
        '/': (context) => const AmplifierHomePage(),
        '/gain_circle': (context) => const GainCirclePage(),
        '/gain_circle_bilateral': (context) => const GainCircleBilateralPage(),
        '/noise_figure_circle': (context) => const ConstantNoiseFigureCirclesPage(),
      },
    );
  }
}
