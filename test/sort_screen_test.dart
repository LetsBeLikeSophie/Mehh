import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/data/demo.dart';
import 'package:mehh/data/photo_library.dart';
import 'package:mehh/data/store.dart';
import 'package:mehh/models/day_group.dart';
import 'package:mehh/models/photo_meta.dart';
import 'package:mehh/providers.dart';
import 'package:mehh/ui/sort_screen.dart';

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
        child: MaterialApp(
          home: SortScreen(kind: SortKind.singles, group: group),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder card() => find.byType(AnimatedSwitcher);

  // 샘플 사진 분석 타이머가 끝날 때까지
  Future<void> flush(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 5));

  testWidgets('위·아래·왼쪽으로 밀면 보류·킵·정리 줄로 가고 남은 장수가 줄어든다', (tester) async {
    await pump(tester);
    expect(find.text('남은 4장 · 전체 4장'), findsOneWidget);

    await tester.drag(card(), const Offset(0, -200)); // 위 = 보류
    await tester.pumpAndSettle();
    await tester.drag(card(), const Offset(0, 200)); // 아래 = 킵
    await tester.pumpAndSettle();
    await tester.drag(card(), const Offset(-200, 0)); // 왼쪽 = 정리
    await tester.pumpAndSettle();

    expect(find.text('남은 1장 · 전체 4장'), findsOneWidget);
    expect(find.text('휴지통으로'), findsOneWidget); // 정리 줄 끝 버튼
    await flush(tester);
  });

  testWidgets('대각선으로 끌어도 처음 방향 한 축으로만 움직인다', (tester) async {
    await pump(tester);
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
    expect(find.text('남은 4장 · 전체 4장'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('줄의 사진을 누르면 가운데로 와서 다시 고를 수 있고, 나갈 때 묻지 않는다', (tester) async {
    await pump(tester);
    await tester.drag(card(), const Offset(-200, 0)); // 정리 줄로
    await tester.pumpAndSettle();
    expect(find.text('남은 3장 · 전체 4장'), findsOneWidget);

    // 정리 줄의 첫 사진을 눌러 불러온 뒤 아래로 = 킵
    final pileThumb = find
        .descendant(
          of: find
              .ancestor(of: find.text('정리'), matching: find.byType(Row))
              .first,
          matching: find.byType(GestureDetector),
        )
        .first;
    await tester.tap(pileThumb);
    await tester.pumpAndSettle();
    await tester.drag(card(), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(find.text('휴지통으로'), findsNothing); // 정리 줄이 비었다

    await tester.tap(find.byTooltip('돌아가기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await flush(tester);
  });
}
