import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/data/demo.dart';
import 'package:mehh/data/photo_library.dart';
import 'package:mehh/data/store.dart';
import 'package:mehh/models/day_group.dart';
import 'package:mehh/models/photo_meta.dart';
import 'package:mehh/providers.dart';
import 'package:mehh/ui/swipe_screen.dart';

void main() {
  final photos = [
    for (var i = 0; i < 4; i++)
      PhotoMeta(
        id: 'p$i',
        takenAt: DateTime(2026, 9, 1 + i * 5, 10),
        width: 100,
        height: 100,
      ),
  ];
  final group = DayGroup(
    id: 'singles',
    kind: DayGroupKind.singles,
    photos: photos,
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryProvider.overrideWithValue(
            DemoPhotoLibrary() as PhotoLibrary,
          ),
          storeProvider.overrideWithValue(MemoryStore()),
        ],
        child: MaterialApp(home: SwipeScreen(group: group)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder card() => find.byType(AnimatedSwitcher);

  testWidgets('위·아래·왼쪽으로 밀면 보류·킵·정리, 남은 장수가 줄어든다', (tester) async {
    await pump(tester);
    expect(find.text('남은 4장'), findsOneWidget);

    await tester.drag(card(), const Offset(0, -200)); // 위 = 보류
    await tester.pumpAndSettle();
    await tester.drag(card(), const Offset(0, 200)); // 아래 = 킵
    await tester.pumpAndSettle();
    await tester.drag(card(), const Offset(-200, 0)); // 왼쪽 = 정리
    await tester.pumpAndSettle();

    expect(find.text('남은 1장'), findsOneWidget);
    expect(find.text('킵 1 · 보류 1 · 정리 1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('대각선으로 끌어도 처음 방향 한 축으로만 움직인다', (tester) async {
    await pump(tester);
    // 처음엔 오른쪽으로 많이, 조금 아래로: 가로로 고정 → 이전 사진(첫 장이라 그대로)
    final g = await tester.startGesture(tester.getCenter(card()));
    await g.moveBy(const Offset(30, 0)); // 터치 슬롭을 넘기는 첫 움직임
    await g.moveBy(const Offset(30, 3));
    await g.moveBy(const Offset(10, 150));
    await tester.pump();
    final t = tester.widget<Transform>(
      find.descendant(of: card(), matching: find.byType(Transform)).first,
    );
    expect(t.transform.getTranslation().y, 0);
    await g.up();
    await tester.pumpAndSettle();
    // 아래로 많이 끌었지만 가로로 고정됐으니 킵이 되지 않는다
    expect(find.text('킵 0 · 보류 0 · 정리 0'), findsOneWidget);
    // 샘플 사진 분석 타이머가 끝날 때까지
    await tester.pump(const Duration(seconds: 5));
  });
}
