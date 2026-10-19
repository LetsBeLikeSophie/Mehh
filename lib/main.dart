import 'package:flutter/material.dart';

import 'theme.dart';

void main() {
  runApp(const MehhApp());
}

class MehhApp extends StatelessWidget {
  const MehhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mehh',
      debugShowCheckedModeBanner: false,
      theme: buildMehhTheme(),
      home: const HomeScreen(),
    );
  }
}

/// 1단계에서 묶음 목록으로 채울 홈 화면 자리.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Image.asset('assets/mehh-goat.png', width: 30, height: 34),
              const SizedBox(width: 6),
              const Text(
                'Mehh',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
