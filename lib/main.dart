import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme.dart';
import 'ui/root_screen.dart';

void main() {
  runApp(const ProviderScope(child: MehhApp()));
}

class MehhApp extends StatelessWidget {
  const MehhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mehh',
      debugShowCheckedModeBanner: false,
      theme: buildMehhTheme(),
      home: const RootScreen(),
      // 웹 미리보기를 넓은 화면에서 열어도 폰 폭으로 보이게
      builder: (context, child) => ColoredBox(
        color: MehhColors.surface,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child,
          ),
        ),
      ),
    );
  }
}
