import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/l10n.dart';
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
      onGenerateTitle: (context) => context.l.appTitle,
      debugShowCheckedModeBanner: false,
      // 한국어·영어. 그 밖의 언어는 영어로 보인다 (supportedLocales 첫 번째 = en)
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
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
