import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../theme/app_theme.dart';

class NetworkAnalyzerApp extends StatelessWidget {
  const NetworkAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Analyzer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
