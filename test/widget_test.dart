import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mehh/ui/widgets.dart';

void main() {
  testWidgets('로고에 앱 이름이 보인다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MehhLogo()));
    expect(find.bySemanticsLabel('Mehh'), findsOneWidget);
  });

  test('천 단위 쉼표', () {
    expect(formatCount(7), '7');
    expect(formatCount(1234), '1,234');
    expect(formatCount(1234567), '1,234,567');
  });
}
