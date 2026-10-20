import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/data/demo.dart';
import 'package:mehh/data/photo_library.dart';
import 'package:mehh/data/store.dart';
import 'package:mehh/models/day_group.dart';
import 'package:mehh/models/photo_meta.dart';
import 'package:mehh/providers.dart';
import 'package:mehh/ui/focus_screen.dart';
import 'package:mehh/ui/sort_screen.dart';
import 'package:mehh/ui/widgets.dart';

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

  Future<void> pump(WidgetTester tester, Widget home) async {
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
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 샘플 사진 분석 타이머가 끝날 때까지
  Future<void> flush(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 5));

  Finder card() => find.byType(AnimatedSwitcher);

  testWidgets('그리드: X를 켜면 휴지통 버튼, 보내면 그 사진만 빠진다', (tester) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    expect(find.text('정리할 사진이 없어요'), findsWidgets);
    await tester.tap(find.byType(XToggle).first);
    await tester.pumpAndSettle();
    expect(find.text('1장 휴지통으로'), findsOneWidget);

    await tester.tap(find.text('1장 휴지통으로'));
    await tester.pumpAndSettle();
    expect(find.text('3장'), findsOneWidget); // 남은 사진 수
    expect(find.text('정리할 사진이 없어요'), findsWidgets);
    await flush(tester);
  });

  testWidgets('크게 보기: 위로 밀면 정리, 아래로 밀면 킵, 그리드에 반영된다', (tester) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    await tester.tap(find.byType(PhotoThumb).first);
    await tester.pumpAndSettle();
    expect(find.byType(FocusScreen), findsOneWidget);

    await tester.drag(card(), const Offset(0, -200)); // 위 = 정리
    await tester.pumpAndSettle();
    await tester.drag(card(), const Offset(0, 200)); // 아래 = 킵
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('1장 휴지통으로'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('크게 보기: 좌우로 넘기면 끝에서 처음으로 이어진다', (tester) async {
    await pump(
      tester,
      FocusScreen(kind: SortKind.singles, group: group, initialId: 'p3'),
    );
    expect(find.text('1 / 4'), findsOneWidget); // 한 장 사진은 최신이 앞
    for (var i = 0; i < 4; i++) {
      await tester.drag(card(), const Offset(-200, 0)); // 다음
      await tester.pumpAndSettle();
    }
    expect(find.text('1 / 4'), findsOneWidget);
    await tester.drag(card(), const Offset(200, 0)); // 이전 = 마지막으로
    await tester.pumpAndSettle();
    expect(find.text('4 / 4'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('크게 보기: 대각선으로 끌어도 처음 방향 한 축으로만 움직인다', (tester) async {
    await pump(
      tester,
      FocusScreen(kind: SortKind.singles, group: group, initialId: 'p3'),
    );
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
    await flush(tester);
  });

  testWidgets('크게 보기: 맨 위 쓰레기통 줄을 눌러도 정리된다', (tester) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    await tester.tap(find.byType(PhotoThumb).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('1장 휴지통으로'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('그리드: [되돌리기]는 처음 상태로, [전체 선택]은 모두 X·다시 누르면 해제', (tester) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    await tester.tap(find.text('전체 선택'));
    await tester.pumpAndSettle();
    expect(find.text('4장 휴지통으로'), findsOneWidget);
    await tester.tap(find.text('선택 해제'));
    await tester.pumpAndSettle();
    expect(find.text('정리할 사진이 없어요'), findsWidgets);

    await tester.tap(find.byType(XToggle).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '되돌리기'));
    await tester.pumpAndSettle();
    expect(find.text('처음 상태로 되돌릴까요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '되돌리기').last);
    await tester.pumpAndSettle();
    expect(find.text('1장 휴지통으로'), findsNothing);
    await flush(tester);
  });

  testWidgets('크게 보기: 좌우는 이동만, 같은 방향으로 한 번 더 밀면 취소', (tester) async {
    await pump(
      tester,
      FocusScreen(kind: SortKind.singles, group: group, initialId: 'p3'),
    );
    await tester.drag(card(), const Offset(-200, 0)); // 다음 (상태 안 바뀜)
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.textContaining('✓'), findsNothing);

    await tester.drag(card(), const Offset(0, 200)); // 킵 → 다음 사진으로
    await tester.pumpAndSettle();
    await tester.drag(card(), const Offset(200, 0)); // 이전 = 킵한 사진
    await tester.pumpAndSettle();
    expect(find.text('✓ 킵'), findsOneWidget);
    await tester.drag(card(), const Offset(0, 200)); // 한 번 더 아래 = 킵 취소
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget); // 취소는 그 자리에
    expect(find.text('✓ 킵'), findsNothing);
    await flush(tester);
  });
}
