import 'package:flutter_test/flutter_test.dart';

import 'package:mehh/main.dart';

void main() {
  testWidgets('홈에 앱 이름이 보인다', (tester) async {
    await tester.pumpWidget(const MehhApp());
    expect(find.text('Mehh'), findsOneWidget);
  });
}
