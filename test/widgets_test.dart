import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mehh/l10n/l10n.dart';
import 'package:mehh/ui/widgets.dart';

void main() {
  testWidgets('로고에 앱 이름이 보인다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: MehhLogo(),
      ),
    );
    expect(find.bySemanticsLabel('Mehh'), findsOneWidget);
  });

  testWidgets('짧은 알림은 3초 동안 남고, 긴 알림도 8초를 넘지 않는다 (UX-98)', (tester) async {
    expect(noteDuration('x' * 300), const Duration(seconds: 8));
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    showNote(ctx, 'Pro가 열렸어요');
    await tester.pumpAndSettle(); // 다 나온 뒤부터 시간이 간다
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.text('Pro가 열렸어요'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Pro가 열렸어요'), findsNothing);
  });

  test('천 단위 쉼표', () {
    expect(formatCount(7), '7');
    expect(formatCount(1234), '1,234');
    expect(formatCount(1234567), '1,234,567');
  });
}
