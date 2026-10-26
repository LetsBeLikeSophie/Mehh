import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/data/billing.dart';
import 'package:mehh/data/pro.dart';
import 'package:mehh/data/demo.dart';
import 'package:mehh/data/handoff.dart';
import 'package:mehh/data/photo_library.dart';
import 'package:mehh/data/store.dart';
import 'package:mehh/l10n/l10n.dart';
import 'package:mehh/logic/pick_stats.dart';
import 'package:mehh/logic/recommend.dart';
import 'package:mehh/models/features.dart';
import 'package:mehh/models/day_group.dart';
import 'package:mehh/models/decision.dart';
import 'package:mehh/models/photo_meta.dart';
import 'package:mehh/models/pick.dart';
import 'package:mehh/providers.dart';
import 'package:mehh/ui/focus_screen.dart';
import 'package:mehh/ui/hold_to_finish.dart';
import 'package:mehh/ui/home_tab.dart';
import 'package:mehh/ui/accuracy_screen.dart';
import 'package:mehh/ui/settings_screen.dart';
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

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    List<Override> extra = const [],
    ProVault? vault,
    Store? store,
    Billing? billing,
    PhotoLibrary? library,
    bool testFree = false,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryProvider.overrideWithValue(
            library ?? DemoPhotoLibrary() as PhotoLibrary,
          ),
          closedTestFreeProvider.overrideWithValue(testFree),
          storeProvider.overrideWithValue(store ?? MemoryStore()),
          proVaultProvider.overrideWithValue(vault ?? MemoryProVault()),
          billingProvider.overrideWithValue(
            billing ?? DemoBilling(korean: true),
          ),
          ...extra,
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 샘플 사진 분석 타이머가 끝날 때까지
  Future<void> flush(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 5));

  Finder card() => find.byType(AnimatedSwitcher);

  // 지금 크게 보고 있는 사진 (낱장 사진은 최신이 앞: p3, p2, p1, p0)
  Finder showing(String id) =>
      find.descendant(of: card(), matching: find.byKey(ValueKey(id)));

  testWidgets('홈: 분석 중에는 "살펴보고 있어요"와 흐린 똑같은 사진 줄 ("없어요"라고 하지 않는다)', (
    tester,
  ) async {
    // 분석이 끝나지 않는 사진첩: 타이밍과 상관없이 늘 "분석 중"을 본다
    await pump(
      tester,
      const Scaffold(body: HomeTab()),
      library: _NeverAnalyzedLibrary(),
    );
    expect(find.text('지금은\n정리할 묶음이 없어요'), findsNothing);
    expect(find.text('사진을\n살펴보고 있어요'), findsOneWidget);
    expect(find.text('똑같은 사진은 다 살펴본 뒤 알려 드려요 · 무료'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('홈: 용량 막대 — 사진·추천 정리·선택·휴지통 (글자 색 = 칸 색, 한 줄)', (tester) async {
    final store = MemoryStore()
      ..freed[monthKey(DateTime.now())] = 5 * 1024 * 1024;
    await pump(tester, const Scaffold(body: HomeTab()), store: store);
    await flush(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('freedBar')), findsOneWidget);
    expect(find.textContaining('사진 '), findsWidgets);
    expect(find.text('휴지통 5MB'), findsOneWidget);
    expect(find.byTooltip('갤러리'), findsOneWidget); // 오른쪽 위 갤러리 열기
    await flush(tester);
  });

  test('갤러리 휴지통에서 되살린 사진은 "휴지통으로 보냄" 기억을 지운다 (바깥·안 장수가 같게)', () async {
    final lib = DemoPhotoLibrary();
    final first = (await lib.loadAll()).first.id;
    final store = MemoryStore()
      ..decisions[first] = Decision(
        photoId: first,
        state: DecisionState.trashed,
        at: DateTime(2026, 10, 1),
      );
    final c = ProviderContainer(
      overrides: [
        closedTestFreeProvider.overrideWithValue(false),
        photoLibraryProvider.overrideWithValue(lib as PhotoLibrary),
        storeProvider.overrideWithValue(store),
      ],
    );
    addTearDown(c.dispose);
    await c.read(libraryProvider.future);
    await Future<void>.delayed(Duration.zero);
    await c.read(decisionsProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      stateOf(c.read(decisionsProvider).value!, first),
      DecisionState.undecided,
    );
  });

  testWidgets('설정: 맨 위 Mehh Pro 줄을 누르면 Pro 안내(구매 복원)가 열린다', (tester) async {
    await pump(tester, const SettingsScreen());
    // 코인은 글자 대신 그림 + 개수
    expect(
      find.descendant(of: find.byType(CoinCount), matching: find.text('3')),
      findsOneWidget,
    );
    expect(find.text('개인정보처리방침'), findsOneWidget);
    await tester.tap(find.text('Mehh Pro'));
    await tester.pumpAndSettle();
    expect(find.text('구매 복원'), findsOneWidget);
  });

  testWidgets('설정: 비공개 테스트 동안 Pro 시트에 가격·코인 남은 수가 없다 (UX-51)', (tester) async {
    await pump(tester, const SettingsScreen(), testFree: true);
    await tester.tap(find.text('Mehh Pro'));
    await tester.pumpAndSettle();
    expect(find.text('비공개 테스트 동안은 모든 묶음 추천이 무료예요'), findsOneWidget);
    expect(find.text('Pro는 정식 출시 때 살 수 있어요'), findsOneWidget);
    expect(find.textContaining('₩'), findsNothing);
    expect(find.textContaining('남음', findRichText: true), findsNothing);
    expect(find.text('구매 복원'), findsOneWidget);
  });

  Override realPlan(Map<String, PhotoFeatures> features) =>
      groupPlanProvider.overrideWith(
        (ref, g) => planGroup(
          g.photos,
          features,
          ref.watch(decisionsProvider).value ?? const {},
        ),
      );

  // 잠기는 추천(비슷한 컷·흔들림)을 만드는 묶음: p0·p1·p2는 10초 간격 같은 장면(p0 베스트, p1 흔들림,
  // p2 비슷한 컷), p3은 5분 뒤 다른 장면. "실수" 사진은 무료라 잠기지 않는다 (P2-A)
  final t0 = DateTime(2026, 9, 1, 10);
  final burstPhotos = [
    for (final (i, d) in [0, 10, 20, 300].indexed)
      PhotoMeta(
        id: 'p$i',
        takenAt: t0.add(Duration(seconds: d)),
        width: 100,
        height: 100,
      ),
  ];
  final paid = {
    for (final (id, sharp) in [('p0', 900.0), ('p1', 5.0), ('p2', 300.0)])
      id: PhotoFeatures(
        id: id,
        hashHi: 1,
        hashLo: 2,
        sharpness: sharp,
        brightness: 120,
      ),
    'p3': const PhotoFeatures(
      id: 'p3',
      hashHi: 0x7FFFFFFF,
      hashLo: 0x7FFFFFFF,
      sharpness: 500,
      brightness: 120,
    ),
  };

  // [Cortex로]는 매번 "N장을 Cortex로 보낼까요?"를 한 번 묻는다 (지우기는 받은 뒤에)
  Future<void> sendCortex(WidgetTester tester) async {
    await tester.tap(find.text('Cortex로'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cortex로 보낼까요?'), findsOneWidget);
    expect(find.text('Cortex에서 AI로 분석해요'), findsOneWidget);
    await tester.tap(find.text('보내기'));
    await tester.pumpAndSettle();
  }

  // 크게 보기에서 길게 눌러 동그라미가 다 찰 때까지
  Future<void> holdToFinish(WidgetTester tester) async {
    final g = await tester.startGesture(tester.getCenter(card()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await g.up();
    await tester.pumpAndSettle();
  }

  // 잠긴 [추천 보기]는 "[코인] 1개로 열까요?"를 묻는다: 누르고 [열기]까지
  Future<void> openLocked(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(find.text('1개로 열까요?'), findsOneWidget);
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  Map<String, PhotoFeatures> darkOn(Set<String> ids) => {
    for (final p in photos)
      p.id: PhotoFeatures(
        id: p.id,
        hashHi: 1,
        hashLo: 2,
        sharpness: 500,
        brightness: ids.contains(p.id) ? 3 : 120,
      ),
  };

  testWidgets('낱장 사진: 까만 사진(실수)은 [추천 보기] 없이 처음부터 X, 끄면 킵', (tester) async {
    await pump(
      tester,
      SortScreen(kind: SortKind.singles, group: group),
      extra: [
        realPlan(darkOn({'p1'})),
      ],
    );
    expect(find.text('1장 휴지통으로'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SortScreen)),
    );
    await tester.tap(find.byType(XToggle).at(2)); // p1 (낱장은 최신이 앞)
    await tester.pumpAndSettle();
    expect(find.text('정리할 사진이 없어요'), findsOneWidget);
    expect(
      stateOf(container.read(decisionsProvider).value!, 'p1'),
      DecisionState.keep,
    );
    await flush(tester);
  });

  testWidgets('[선택 해제]는 표시 없음: 연 묶음의 추천이 남아 [추천 보기]로 다시 받는다', (tester) async {
    final day = DayGroup(
      id: 'day-p0',
      kind: DayGroupKind.day,
      photos: burstPhotos,
    );
    await pump(
      tester,
      SortScreen(kind: SortKind.day, group: day),
      extra: [realPlan(paid)],
    );
    await openLocked(tester, '추천 보기 · 2장');
    await tester.tap(find.text('전체 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택 해제'));
    await tester.pumpAndSettle();
    expect(find.text('정리할 사진이 없어요'), findsOneWidget);
    expect(find.text('추천 보기 · 2장'), findsOneWidget); // 추천은 그대로
    await tester.tap(find.text('추천 보기 · 2장'));
    await tester.pumpAndSettle();
    expect(find.text('2장 휴지통으로'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('잠긴 묶음을 직접 정리해 한 번 보내면 "다 봤어요"', (tester) async {
    final day = DayGroup(
      id: 'day-p0',
      kind: DayGroupKind.day,
      photos: burstPhotos,
    );
    await pump(
      tester,
      SortScreen(kind: SortKind.day, group: day),
      extra: [realPlan(paid)],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SortScreen)),
    );
    expect(container.read(groupStatusProvider(day)), GroupStatus.needsWork);
    await tester.tap(find.byType(XToggle).at(3)); // p3을 직접 X
    await tester.pumpAndSettle();
    await tester.tap(find.text('1장 휴지통으로'));
    await tester.pumpAndSettle();
    final rest = DayGroup(
      id: 'day-p0',
      kind: DayGroupKind.day,
      photos: burstPhotos.sublist(0, 3),
    );
    expect(container.read(groupStatusProvider(rest)), GroupStatus.done);
    await flush(tester);
  });

  testWidgets('설정: Cortex가 있으면 개인정보 안내에 Cortex AI 줄 (사진·캡처)', (tester) async {
    await pump(
      tester,
      const SettingsScreen(),
      extra: [cortexInstalledProvider.overrideWith((ref) async => true)],
    );
    expect(find.textContaining('Cortex에서 AI로 분석해요'), findsOneWidget);
    expect(find.textContaining('고른 사진·캡처만'), findsOneWidget);
    // 1.10.0부터 모든 사진을 보낼 수 있다: "캡처만"이라고 하지 않는다 (시니어 리뷰 2026-10-24 S-1)
    expect(find.textContaining('고른 캡처만'), findsNothing);
  });

  testWidgets('캡처: [추천 보기 · N장]을 누르면 N장 모두 X (오래된 캡처)', (tester) async {
    final old = [
      for (var i = 0; i < 3; i++)
        PhotoMeta(
          id: 's$i',
          takenAt: DateTime(2026, 1, 1 + i),
          width: 100,
          height: 200,
          isScreenshot: true,
        ),
      PhotoMeta(
        id: 'new',
        takenAt: DateTime.now(),
        width: 100,
        height: 200,
        isScreenshot: true,
      ),
    ];
    final shots = DayGroup(
      id: 'shots',
      kind: DayGroupKind.screenshots,
      photos: old,
    );
    await pump(tester, SortScreen(kind: SortKind.screenshots, group: shots));
    await tester.tap(find.text('추천 보기 · 3장'));
    await tester.pumpAndSettle();
    expect(find.text('3장 휴지통으로'), findsOneWidget);
    expect(find.text('오래됨'), findsNWidgets(3));
    await flush(tester);
  });

  testWidgets('처음부터 X만 보내면 보지 못한 추천은 "거절"로 세지 않는다 (취향 학습이 끄지 않게)', (
    tester,
  ) async {
    // q0·q1: 20초 간격 같은 화면, q1 흔들림 → 흔들림 추천(보이지 않음) / q2: 까만 사진 → 처음부터 X
    final t = DateTime(2026, 9, 1, 10);
    final qs = [
      PhotoMeta(id: 'q0', takenAt: t, width: 100, height: 100),
      PhotoMeta(
        id: 'q1',
        takenAt: t.add(const Duration(seconds: 20)),
        width: 100,
        height: 100,
      ),
      PhotoMeta(
        id: 'q2',
        takenAt: DateTime(2026, 9, 5),
        width: 100,
        height: 100,
      ),
    ];
    final g = DayGroup(id: 'singles', kind: DayGroupKind.singles, photos: qs);
    final f = {
      'q0': const PhotoFeatures(
        id: 'q0',
        hashHi: 1,
        hashLo: 2,
        sharpness: 500,
        brightness: 120,
      ),
      'q1': const PhotoFeatures(
        id: 'q1',
        hashHi: 1,
        hashLo: 2,
        sharpness: 5,
        brightness: 120,
      ),
      'q2': const PhotoFeatures(
        id: 'q2',
        hashHi: 9,
        hashLo: 9,
        sharpness: 500,
        brightness: 3,
      ),
    };
    await pump(
      tester,
      SortScreen(kind: SortKind.singles, group: g),
      extra: [realPlan(f)],
    );
    expect(find.text('1장 휴지통으로'), findsOneWidget); // q2만 처음부터 X
    await tester.tap(find.text('1장 휴지통으로'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SortScreen)),
    );
    final stats = PickStats.of(await container.read(storeProvider).loadPicks());
    expect(stats.suggested, 1);
    expect(stats.accepted, 1);
    expect(stats.byTag.containsKey('blurry'), isFalse);
    expect(mutedReasons(stats), isEmpty);
    await flush(tester);
  });

  testWidgets('숨은 정확도 화면: 종류별 받아들인 비율', (tester) async {
    final store = MemoryStore();
    final at = DateTime(2026, 10, 22);
    await store.addPicks([
      PickRecord(
        at: at,
        kind: 'day',
        tag: 'burst',
        suggested: true,
        sent: true,
      ),
      PickRecord(
        at: at,
        kind: 'day',
        tag: 'burst',
        suggested: true,
        sent: false,
      ),
      PickRecord(
        at: at,
        kind: 'screenshots',
        tag: 'oldShot',
        suggested: true,
        sent: true,
      ),
    ]);
    await pump(tester, const AccuracyScreen(), store: store);
    expect(find.text('50%'), findsOneWidget); // 큰 숫자는 그날의 묶음만 (1/2)
    expect(find.textContaining('모든 종류 합계 67%'), findsOneWidget);
    expect(find.textContaining('그날의 묶음  1/2장'), findsOneWidget);
    expect(find.textContaining('캡처  1/1장'), findsOneWidget);
  });

  testWidgets('캡처: X 하나를 켰다 꺼서 킵해도 추천이 남아 있으면 홈은 "다 봤어요"가 아니다', (tester) async {
    final shots = DayGroup(
      id: 'shots',
      kind: DayGroupKind.screenshots,
      photos: [
        for (var i = 0; i < 3; i++)
          PhotoMeta(
            id: 's$i',
            takenAt: DateTime(2026, 1, 1 + i),
            width: 100,
            height: 200,
            isScreenshot: true,
          ),
      ],
    );
    await pump(tester, SortScreen(kind: SortKind.screenshots, group: shots));
    await tester.tap(find.byType(XToggle).first); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byType(XToggle).first); // 끄기 = 킵
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(SortScreen)),
    );
    expect(c.read(groupStatusProvider(shots)), GroupStatus.nothing);
    await flush(tester);
  });

  testWidgets('캡처 연속 묶음: 오래된 것은 추천대로 보내도 확인 창 없음, 최근 것은 전부 X면 확인', (
    tester,
  ) async {
    PhotoMeta shot(String id, DateTime t) => PhotoMeta(
      id: id,
      takenAt: t,
      width: 100,
      height: 200,
      isScreenshot: true,
    );
    final oldT = DateTime(2026, 1, 1, 10);
    final newT = DateTime.now().subtract(const Duration(days: 1));
    final g = DayGroup(
      id: 'shots',
      kind: DayGroupKind.screenshots,
      photos: [
        shot('o1', oldT),
        shot('o2', oldT.add(const Duration(seconds: 5))),
        shot('n1', newT),
        shot('n2', newT.add(const Duration(seconds: 5))),
      ],
    );
    final f = {
      for (final id in ['o1', 'o2'])
        id: PhotoFeatures(
          id: id,
          hashHi: 1,
          hashLo: 1,
          sharpness: 500,
          brightness: 120,
        ),
      for (final id in ['n1', 'n2'])
        id: PhotoFeatures(
          id: id,
          hashHi: 0x7FFFFFFF,
          hashLo: 0x7FFFFFFF,
          sharpness: 500,
          brightness: 120,
        ),
    };
    await pump(
      tester,
      SortScreen(kind: SortKind.screenshots, group: g),
      extra: [analysisProvider.overrideWith(() => _FixedAnalysis(f))],
    );
    // 전부 X하면 최근 연속 묶음만 장면 확인 (오래된 묶음은 앱이 통째로 추천하니 세지 않는다)
    await tester.tap(find.text('전체 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4장 휴지통으로'));
    await tester.pumpAndSettle();
    expect(find.text('1개 장면은 사진이 하나도 안 남아요'), findsOneWidget);
    await tester.tap(find.text('다시 볼게요'));
    await tester.pumpAndSettle();
    // 추천대로(오래된 묶음 둘 + 최근 묶음의 지난 장) 보내면 확인 창 없음
    await tester.tap(find.text('선택 해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('추천 보기 · 3장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3장 휴지통으로'));
    await tester.pumpAndSettle();
    expect(find.textContaining('장면은 사진이 하나도 안 남아요'), findsNothing);
    await flush(tester);
  });

  testWidgets('잠긴 묶음에서도 실수 사진은 무료로 처음부터 X, 자물쇠는 비슷한 컷·흔들림에만', (tester) async {
    final day = DayGroup(
      id: 'day-p0',
      kind: DayGroupKind.day,
      photos: burstPhotos,
    );
    final f = {
      ...paid,
      'p3': const PhotoFeatures(
        id: 'p3',
        hashHi: 0x7FFFFFFF,
        hashLo: 0x7FFFFFFF,
        sharpness: 500,
        brightness: 3, // 까만 사진 = 실수
      ),
    };
    await pump(
      tester,
      SortScreen(kind: SortKind.day, group: day),
      extra: [realPlan(f)],
    );
    expect(find.text('1장 휴지통으로'), findsOneWidget); // 실수 사진만 처음부터 X
    expect(
      find.text('추천 보기 · 3장'),
      findsOneWidget,
    ); // 누르면 X가 되는 장수 (잠긴 2 + 실수 1)
    expect(find.text('실수'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget); // [추천 보기]에 자물쇠
    await openLocked(tester, '추천 보기 · 3장');
    expect(find.text('3장 휴지통으로'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing); // 열리면 자물쇠가 사라진다
    await flush(tester);
  });

  testWidgets('무료 묶음을 다 쓴 달의 Pro 안내: "지금 무료로: 캡처 추천 N장 보기" → 캡처 화면', (
    tester,
  ) async {
    final shots = DayGroup(
      id: 'shots',
      kind: DayGroupKind.screenshots,
      photos: [
        for (var i = 0; i < 3; i++)
          PhotoMeta(
            id: 's$i',
            takenAt: DateTime(2026, 1, 1 + i),
            width: 100,
            height: 200,
            isScreenshot: true,
          ),
      ],
    );
    final now = DateTime.now();
    await pump(
      tester,
      const SettingsScreen(),
      vault: MemoryProVault(
        ProState(freeMonth: monthKey(now), freeUsed: freeGroupsPerMonth),
      ),
      extra: [
        libraryProvider.overrideWith(
          () => _FixedLibrary(
            LibraryState(photos: shots.photos, groups: [shots]),
          ),
        ),
      ],
    );
    await tester.tap(find.text('Mehh Pro'));
    await tester.pumpAndSettle();
    expect(find.text('지금 무료로: 캡처 추천 3장 보기 ›'), findsOneWidget);
    await tester.tap(find.text('지금 무료로: 캡처 추천 3장 보기 ›'));
    await tester.pumpAndSettle();
    expect(find.text('추천 보기 · 3장'), findsOneWidget);
    await flush(tester);
  });

  testWidgets(
    '코인 0개: 길게 눌러 끝낸 뒤 Pro 안내의 "지금 무료로" → 캡처 화면이 열려 있고, 뒤로 가면 처음 화면 (UX-52)',
    (tester) async {
      final shots = DayGroup(
        id: 'shots',
        kind: DayGroupKind.screenshots,
        photos: [
          for (var i = 0; i < 3; i++)
            PhotoMeta(
              id: 's$i',
              takenAt: DateTime(2026, 1, 1 + i),
              width: 100,
              height: 200,
              isScreenshot: true,
            ),
        ],
      );
      final day = DayGroup(
        id: 'day-p0',
        kind: DayGroupKind.day,
        photos: photos,
      );
      await pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SortScreen(kind: SortKind.day, group: day),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
        vault: MemoryProVault(
          ProState(
            freeMonth: monthKey(DateTime.now()),
            freeUsed: freeGroupsPerMonth,
          ),
        ),
        extra: [
          libraryProvider.overrideWith(
            () => _FixedLibrary(
              LibraryState(
                photos: [...photos, ...shots.photos],
                groups: [day, shots],
              ),
            ),
          ),
        ],
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(XToggle).first);
      await tester.pumpAndSettle();
      // 그리드 제목 옆 빈 곳을 길게 눌러 끝내기
      final g = await tester.startGesture(
        tester.getTopRight(find.byType(SortScreen)) + const Offset(-60, 140),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      await g.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('휴지통으로'));
      await tester.pumpAndSettle();
      expect(find.text('지금 무료로: 캡처 추천 3장 보기 ›'), findsOneWidget);
      await tester.tap(find.text('지금 무료로: 캡처 추천 3장 보기 ›'));
      await tester.pumpAndSettle();
      expect(find.text('추천 보기 · 3장'), findsOneWidget); // 캡처 화면이 남아 있다
      await tester.tap(find.byType(MehhBackButton));
      await tester.pumpAndSettle();
      expect(find.text('열기'), findsOneWidget); // 묶음 화면은 이미 닫혔다
      expect(find.byType(SortScreen), findsNothing);
      await flush(tester);
    },
  );

  testWidgets('그리드: X를 켜면 휴지통 버튼, 보내면 그 사진만 빠진다', (tester) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    expect(find.text('정리할 사진이 없어요'), findsWidgets);
    await tester.tap(find.byType(XToggle).first);
    await tester.pumpAndSettle();
    expect(find.text('1장 휴지통으로'), findsOneWidget);

    await tester.tap(find.text('1장 휴지통으로'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3장'), findsOneWidget); // 남은 사진 수
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

  testWidgets('크게 보기: 길게 누르면 "N장 휴지통으로" [계속 보기]/[휴지통으로] → 돌아가서 바로 보낸다', (
    tester,
  ) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    await tester.tap(find.byType(PhotoThumb).first);
    await tester.pumpAndSettle();
    await tester.drag(card(), const Offset(0, -200)); // 위 = 정리
    await tester.pumpAndSettle();
    await tester.drag(card(), const Offset(0, -200));
    await tester.pumpAndSettle();

    await holdToFinish(tester);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('2장 휴지통으로'),
      ),
      findsOneWidget,
    ); // 제목 = 버튼과 같은 말
    await tester.tap(find.text('계속 보기')); // 취소하면 그대로
    await tester.pumpAndSettle();
    expect(find.byType(FocusScreen), findsOneWidget);

    await holdToFinish(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('휴지통으로'));
    await tester.pumpAndSettle();
    expect(find.byType(FocusScreen), findsNothing);
    expect(find.textContaining('  2장'), findsOneWidget); // 남은 사진
    expect(
      find.textContaining(RegExp(r'✓ 2장 · .+ 휴지통으로 보냈어요')),
      findsOneWidget,
    );
    await flush(tester);
  });

  testWidgets('그리드: 길게 눌러 가운데 동그라미가 차면 "N장 휴지통으로" → 보낸다', (tester) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    await tester.tap(find.byType(XToggle).at(0));
    await tester.pumpAndSettle();
    // 제목 옆 빈 곳을 길게
    final g = await tester.startGesture(
      tester.getTopRight(find.byType(SortScreen)) + const Offset(-60, 140),
    );
    await tester.pump(const Duration(milliseconds: 300));
    // 그냥 누르는 동안(0.5초 전)에는 동그라미가 안 보인다
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('1장 휴지통으로'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('휴지통으로'));
    await tester.pumpAndSettle();
    expect(find.textContaining('  3장'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('큰 동영상: 50MB 넘는 것만 용량 큰 순, 길이·용량 표시, 선택해서 휴지통으로', (tester) async {
    final t = DateTime(2026, 10, 1);
    PhotoMeta v(String id, int mb, int sec) => PhotoMeta(
      id: id,
      takenAt: t,
      width: 1920,
      height: 1080,
      isVideo: true,
      durationSec: sec,
      sizeBytes: mb * 1024 * 1024,
    );
    final videos = DayGroup(
      id: 'videos',
      kind: DayGroupKind.videos,
      photos: [v('v1', 900, 125), v('v2', 300, 40)],
    );
    await pump(tester, SortScreen(kind: SortKind.videos, group: videos));
    expect(find.textContaining('큰 동영상', findRichText: true), findsWidgets);
    expect(find.text('2:05 · 900MB'), findsOneWidget);
    expect(find.text('0:40 · 300MB'), findsOneWidget);
    expect(find.text('추천 보기 · 0장'), findsNothing); // 앱이 골라 주지 않는다
    expect(find.textContaining('2개'), findsWidgets); // 홈 줄과 같은 단위
    expect(find.text('고른 동영상이 없어요'), findsOneWidget); // 빈 상태도 동영상 말로 (UX-50)
    expect(find.text('정리할 사진이 없어요'), findsNothing);
    await tester.tap(find.byType(XToggle).at(0));
    await tester.pumpAndSettle();
    expect(find.text('1개 휴지통으로'), findsOneWidget);
    expect(find.text('1장 휴지통으로'), findsNothing);
    await flush(tester);
  });

  testWidgets('큰 동영상: Cortex가 깔려 있어도 [Cortex로]가 없다 (Cortex는 사진·캡처만)', (
    tester,
  ) async {
    PhotoMeta v(String id) => PhotoMeta(
      id: id,
      takenAt: DateTime(2026, 10, 1),
      width: 1920,
      height: 1080,
      isVideo: true,
      durationSec: 60,
      sizeBytes: 200 * 1024 * 1024,
    );
    final videos = DayGroup(
      id: 'videos',
      kind: DayGroupKind.videos,
      photos: [v('v1'), v('v2')],
    );
    await pump(
      tester,
      SortScreen(kind: SortKind.videos, group: videos),
      extra: [cortexInstalledProvider.overrideWith((ref) async => true)],
    );
    await tester.tap(find.byType(XToggle).at(0));
    await tester.pumpAndSettle();
    expect(find.byType(XToggle), findsNWidgets(2));
    expect(find.text('Cortex로'), findsNothing);
    await flush(tester);
  });

  testWidgets('큰 동영상 크게 보기: 길이·용량·날짜가 보인다 (UX-49)', (tester) async {
    final videos = DayGroup(
      id: 'videos',
      kind: DayGroupKind.videos,
      photos: [
        PhotoMeta(
          id: 'v1',
          takenAt: DateTime(2026, 10, 3, 12),
          width: 1920,
          height: 1080,
          isVideo: true,
          durationSec: 760,
          sizeBytes: 1536 * 1024 * 1024,
        ),
      ],
    );
    await pump(
      tester,
      FocusScreen(kind: SortKind.videos, group: videos, initialId: 'v1'),
    );
    expect(find.text('12:40 · 1.5GB · 10월 3일'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('Cortex를 받으러 가서 설치하고 돌아오면 [Cortex로]가 바로 보내기를 묻는다 (UX-56)', (
    tester,
  ) async {
    final handoff = _FakeHandoff(installed: false);
    await pump(
      tester,
      SortScreen(kind: SortKind.singles, group: group),
      extra: [handoffProvider.overrideWithValue(handoff)],
    );
    await tester.tap(find.byType(XToggle).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cortex로'));
    await tester.pumpAndSettle();
    expect(find.text('Cortex가 필요해요'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    // 스토어에서 설치하고 최근 앱으로 돌아온다
    handoff.installed = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cortex로'));
    await tester.pumpAndSettle();
    expect(find.text('Cortex가 필요해요'), findsNothing);
    expect(find.text('1장을 Cortex로 보낼까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await flush(tester);
  });

  testWidgets('Cortex: 이미 보낸 사진이 섞여 있으면 보낼까요? 창이 그 장수를 말한다 (UX-57)', (
    tester,
  ) async {
    final five = [
      for (var i = 0; i < 5; i++)
        PhotoMeta(
          id: 'c$i',
          takenAt: DateTime(2026, 9, 1 + i * 5, 10),
          width: 100,
          height: 100,
        ),
    ];
    // 지난주 [나중에]로 남긴 "Cortex에 있음" 2장
    final store = MemoryStore()..cortexSent.addAll({'c0': true, 'c1': true});
    await pump(
      tester,
      SortScreen(
        kind: SortKind.singles,
        group: DayGroup(
          id: 'singles',
          kind: DayGroupKind.singles,
          photos: five,
        ),
      ),
      store: store,
      extra: [
        cortexInstalledProvider.overrideWith((ref) async => true),
        handoffProvider.overrideWithValue(_FakeHandoff()),
      ],
    );
    expect(find.text('Cortex에 있음'), findsNWidgets(2));
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byType(XToggle).at(i));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cortex로'));
    await tester.pumpAndSettle();
    expect(find.text('5장을 Cortex로 보낼까요?'), findsOneWidget);
    expect(find.textContaining('이미 Cortex로 보낸 2장도 다시 보내요'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await flush(tester);
  });

  testWidgets('Cortex가 없으면 [Cortex로]를 눌렀을 때 받으러 가기 안내', (tester) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    await tester.tap(find.byType(XToggle).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cortex로'));
    await tester.pumpAndSettle();
    expect(find.text('Cortex가 필요해요'), findsOneWidget);
    expect(find.text('받으러 가기'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await flush(tester);
  });

  testWidgets('묶음 이름: 제목을 누르면 바꾸고, [원래 이름으로]로 되돌린다', (tester) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    final title = find.textContaining('낱장 사진');
    expect(title, findsWidgets);
    await tester.tap(title.first);
    await tester.pumpAndSettle();
    expect(find.text('묶음 이름'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '여행 사진');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('여행 사진'), findsOneWidget);
    // 되돌리기
    await tester.tap(find.textContaining('여행 사진'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('원래 이름으로'));
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('여행 사진'), findsNothing);
    expect(find.textContaining('낱장 사진'), findsWidgets);
    await flush(tester);
  });

  testWidgets('묶음 이름: 첫 사진을 휴지통으로 보내 묶음 id가 바뀌어도 바꾼 이름이 남는다', (tester) async {
    final store = MemoryStore();
    final before = DayGroup(
      id: 'day-p0',
      kind: DayGroupKind.day,
      photos: photos,
    );
    await pump(
      tester,
      SortScreen(kind: SortKind.day, group: before),
      store: store,
    );
    await tester.tap(find.textContaining('9월 1일').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '제주 여행');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('제주 여행'), findsOneWidget);
    await flush(tester);

    // 첫 사진(p0)이 휴지통으로 가면 다시 묶일 때 id가 day-p1이 된다
    final after = DayGroup(
      id: 'day-p1',
      kind: DayGroupKind.day,
      photos: photos.sublist(1),
    );
    await pump(
      tester,
      SortScreen(kind: SortKind.day, group: after),
      store: store,
    );
    expect(find.textContaining('제주 여행'), findsOneWidget);
    // 홈 줄도 같은 함수로 이름을 찾는다
    expect(groupNameOf(await store.loadNames(), after), '제주 여행');
    await flush(tester);
  });

  testWidgets('묶음 이름: 1장만 남겨 낱장 사진으로 옮겨 가도 낱장 줄·제목은 그대로 (UX-47)', (
    tester,
  ) async {
    final store = MemoryStore();
    await pump(
      tester,
      SortScreen(
        kind: SortKind.day,
        group: DayGroup(id: 'day-p0', kind: DayGroupKind.day, photos: photos),
      ),
      store: store,
    );
    await tester.tap(find.textContaining('9월 1일').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '지우 돌잔치');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    await flush(tester);

    // 나머지를 보내 p2만 남으면 묶음이 사라지고 p2는 낱장 사진으로 간다
    final singles = DayGroup(
      id: 'singles',
      kind: DayGroupKind.singles,
      photos: [photos[2]],
    );
    await pump(
      tester,
      SortScreen(kind: SortKind.singles, group: singles),
      store: store,
    );
    expect(find.textContaining('지우 돌잔치'), findsNothing);
    expect(find.textContaining('낱장 사진'), findsWidgets);
    final names = await store.loadNames();
    expect(groupNameOf(names, singles), isNull);

    // 둘로 갈라지면 원래 id를 가진 쪽만 이름을 갖는다
    final front = DayGroup(
      id: 'day-p0',
      kind: DayGroupKind.day,
      photos: photos.sublist(0, 2),
    );
    final back = DayGroup(
      id: 'day-p2',
      kind: DayGroupKind.day,
      photos: photos.sublist(2),
    );
    expect(groupNameOf(names, front, all: [front, back]), '지우 돌잔치');
    expect(groupNameOf(names, back, all: [front, back]), isNull);
    await flush(tester);
  });

  testWidgets('그리드: 화면 왼쪽 끝에서 안쪽으로 밀면 뒤로 간다 (사진 선택 대신)', (tester) async {
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SortScreen(kind: SortKind.singles, group: group),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byType(SortScreen), findsOneWidget);
    final y = tester.getCenter(find.byType(PhotoThumb).first).dy;
    await tester.dragFrom(Offset(4, y), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(find.byType(SortScreen), findsNothing);
    expect(find.text('정리할 사진이 없어요'), findsNothing);
    await flush(tester);
  });

  testWidgets('그리드: 사진 위에서 옆으로 끌면 지나간 사진이 한꺼번에 선택되고, 다시 끌면 풀린다', (
    tester,
  ) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    final from = tester.getCenter(find.byType(PhotoThumb).at(0));
    final to = tester.getCenter(find.byType(PhotoThumb).at(2));
    final g = await tester.startGesture(from);
    await g.moveBy(const Offset(20, 0)); // 옆으로 먼저
    await tester.pump();
    await g.moveTo(to);
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('3장 휴지통으로'), findsOneWidget);
    // 선택된 사진에서 시작하면 지나간 사진을 푼다
    final g2 = await tester.startGesture(from);
    await g2.moveBy(const Offset(20, 0));
    await tester.pump();
    await g2.moveTo(tester.getCenter(find.byType(PhotoThumb).at(1)));
    await tester.pump();
    await g2.up();
    await tester.pumpAndSettle();
    expect(find.text('1장 휴지통으로'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('그리드: 누른 채 손가락을 움직이면(아래로 끌기) 끝내기로 가지 않는다', (tester) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    await tester.tap(find.byType(XToggle).at(0));
    await tester.pumpAndSettle();
    final g = await tester.startGesture(
      tester.getTopRight(find.byType(SortScreen)) + const Offset(-60, 140),
    );
    await tester.pump(const Duration(milliseconds: 600)); // 길게 누르기로 잡힌 뒤
    await g.moveBy(const Offset(0, 40));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await flush(tester);
  });

  testWidgets('크게 보기: 동그라미가 다 차기 전에 손을 떼면 아무 일도 없다', (tester) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    await tester.tap(find.byType(PhotoThumb).first);
    await tester.pumpAndSettle();
    final g = await tester.startGesture(tester.getCenter(card()));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(CircularProgressIndicator), findsOneWidget); // 차오르는 중
    await g.up();
    await tester.pumpAndSettle();
    expect(find.textContaining('끝낼까요?'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await flush(tester);
  });

  testWidgets('크게 보기: X가 없으면 길게 눌러 "끝낼까요?" → 그냥 돌아간다', (tester) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    await tester.tap(find.byType(PhotoThumb).first);
    await tester.pumpAndSettle();
    await holdToFinish(tester);
    await tester.pumpAndSettle();
    expect(find.text('정리할 사진이 없어요. 끝낼까요?'), findsOneWidget);
    await tester.tap(find.text('끝내기'));
    await tester.pumpAndSettle();
    expect(find.byType(FocusScreen), findsNothing);
    expect(find.textContaining('  4장'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('크게 보기: 선택한 게 있을 때 멈추면 "길게 누르면 정리를 끝낼 수 있어요" (5번까지, 한 번 쓰면 그만)', (
    tester,
  ) async {
    final store = MemoryStore();
    await pump(
      tester,
      FocusScreen(kind: SortKind.singles, group: group, initialId: 'p3'),
      store: store,
    );
    Finder hint() => find.ancestor(
      of: find.text('길게 누르면 정리를 끝낼 수 있어요'),
      matching: find.byType(AnimatedOpacity),
    );
    double opacity() => tester.widget<AnimatedOpacity>(hint()).opacity;
    // 선택한 게 없으면 멈춰도 안 뜬다
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(opacity(), 0);
    // 하나 선택하고 멈추면 뜬다
    await tester.drag(card(), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(opacity(), 1);
    await tester.pump(const Duration(seconds: 4)); // 잠깐 뒤 사라진다
    expect(opacity(), 0);

    // 통틀어 5번 보였으면 더 안 뜬다
    store.counters[finishHintKey] = 5;
    await tester.drag(card(), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(opacity(), 0);

    // 길게 누르기를 한 번 쓰면 그 뒤로 안 뜬다
    store.counters[finishHintKey] = 0;
    await holdToFinish(tester);
    expect(store.counters[finishUsedKey], 1);
    await tester.tap(find.text('계속 보기'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(opacity(), 0);
    await flush(tester);
  });

  testWidgets('크게 보기: 좌우로 넘기면 끝에서 처음으로 이어진다', (tester) async {
    await pump(
      tester,
      FocusScreen(kind: SortKind.singles, group: group, initialId: 'p3'),
    );
    expect(showing('p3'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.drag(card(), const Offset(-200, 0)); // 다음
      await tester.pumpAndSettle();
    }
    expect(showing('p3'), findsOneWidget);
    await tester.drag(card(), const Offset(200, 0)); // 이전 = 마지막으로
    await tester.pumpAndSettle();
    expect(showing('p0'), findsOneWidget);
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

  testWidgets('크게 보기: 아래 킵 줄을 눌러도 킵, 되돌리기 버튼은 없다', (tester) async {
    await pump(
      tester,
      FocusScreen(kind: SortKind.singles, group: group, initialId: 'p3'),
    );
    expect(find.byIcon(Icons.undo), findsNothing);
    await tester.tap(find.text('킵'));
    await tester.pumpAndSettle();
    await tester.drag(card(), const Offset(200, 0)); // 이전 = 방금 킵한 사진
    await tester.pumpAndSettle();
    expect(find.text('✓ 킵'), findsOneWidget);
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

  testWidgets('그리드: [전체 선택]은 모두 X, 다시 누르면 해제 ([처음대로]는 없다)', (tester) async {
    await pump(tester, SortScreen(kind: SortKind.singles, group: group));
    await tester.tap(find.text('전체 선택'));
    await tester.pumpAndSettle();
    expect(find.text('4장 휴지통으로'), findsOneWidget);
    await tester.tap(find.text('선택 해제'));
    await tester.pumpAndSettle();
    expect(find.text('정리할 사진이 없어요'), findsWidgets);

    expect(find.text('처음대로'), findsNothing);
    await flush(tester);
  });

  testWidgets('크게 보기: 좌우는 이동만, 위는 언제나 정리·아래는 언제나 킵', (tester) async {
    await pump(
      tester,
      FocusScreen(kind: SortKind.singles, group: group, initialId: 'p3'),
    );
    await tester.drag(card(), const Offset(-200, 0)); // 다음 (상태 안 바뀜)
    await tester.pumpAndSettle();
    expect(showing('p2'), findsOneWidget);
    expect(find.textContaining('✓'), findsNothing);

    await tester.drag(card(), const Offset(0, 200)); // 킵 → 다음 사진으로
    await tester.pumpAndSettle();
    await tester.drag(card(), const Offset(200, 0)); // 이전 = 킵한 사진
    await tester.pumpAndSettle();
    expect(find.text('✓ 킵'), findsOneWidget);
    await tester.drag(card(), const Offset(0, 200)); // 한 번 더 아래도 킵 → 다음
    await tester.pumpAndSettle();
    expect(showing('p1'), findsOneWidget);
    await tester.drag(card(), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(find.text('✓ 킵'), findsOneWidget);
    await tester.drag(card(), const Offset(0, -200)); // 위 = 정리 → 다음
    await tester.pumpAndSettle();
    await tester.drag(card(), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(showing('p2'), findsOneWidget);
    expect(find.text('✕ 정리'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('캡처: 추천이 없으면 [추천 보기]도 없고, 홈 상태는 X가 있을 때만 할 일', (tester) async {
    final shots = DayGroup(
      id: 'shots',
      kind: DayGroupKind.screenshots,
      photos: photos,
    );
    await pump(tester, SortScreen(kind: SortKind.screenshots, group: shots));
    expect(find.textContaining('추천 보기'), findsNothing);
    expect(find.text('Cortex로'), findsNothing); // 고르기 전엔 없다

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SortScreen)),
    );
    expect(container.read(groupStatusProvider(shots)), GroupStatus.nothing);

    await tester.tap(find.byType(XToggle).first); // X 켜기
    await tester.pumpAndSettle();
    expect(container.read(groupStatusProvider(shots)), GroupStatus.needsWork);
    await tester.tap(find.byType(XToggle).first); // X 끄기 = 킵
    await tester.pumpAndSettle();
    expect(container.read(groupStatusProvider(shots)), GroupStatus.done);
    await flush(tester);
  });

  testWidgets('그날의 묶음: [추천 보기]를 눌러야 X, 이번 달 무료 묶음으로 열고 연 묶음은 계속 열림', (
    tester,
  ) async {
    final day = DayGroup(
      id: 'day-p0',
      kind: DayGroupKind.day,
      photos: burstPhotos,
    );
    // 실제 planGroup을 거친다 (p1 흔들림, p2 비슷한 컷)
    await pump(
      tester,
      SortScreen(kind: SortKind.day, group: day),
      extra: [realPlan(paid)],
    );

    expect(find.text('2장 휴지통으로'), findsNothing); // 누르기 전엔 X 없음
    expect(find.text('흔들림'), findsNothing); // 이유 표시는 X가 쳐진 사진에만

    // 잠긴 묶음: 누르면 무료 묶음을 쓸지 먼저 묻는다 (설명 줄 대신)
    await tester.tap(find.text('추천 보기 · 2장'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('코인 3개'), findsWidgets); // 남은 코인은 제목 옆 아이콘
    await tester.tap(find.text('취소')); // 취소하면 아무것도 안 쓴다
    await tester.pumpAndSettle();
    expect(find.text('2장 휴지통으로'), findsNothing);
    await openLocked(tester, '추천 보기 · 2장');
    expect(find.text('2장 휴지통으로'), findsOneWidget);
    // 추천이 켜진 상태: 이유 표시, 버튼은 같은 모양에 앞 칸만 체크
    expect(find.text('흔들림'), findsOneWidget);
    expect(find.text('비슷한 컷'), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    // 다시 누르면 추천 X만 풀리고(끄기), 또 누르면 다시 켜진다 (2026-10-24 Sophie)
    await tester.tap(find.text('추천 보기 · 2장'));
    await tester.pumpAndSettle();
    expect(find.text('2장 휴지통으로'), findsNothing);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    await tester.tap(find.text('추천 보기 · 2장'));
    await tester.pumpAndSettle();
    expect(find.text('2장 휴지통으로'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SortScreen)),
    );
    final now = DateTime.now();

    // 추천 하나(p2)를 빼고 보내면 정확도 기록이 남는다
    await tester.tap(find.byType(XToggle).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1장 휴지통으로'));
    await tester.pumpAndSettle();
    final picks = await container.read(storeProvider).loadPicks();
    // 무료가 아직 남았으니 Pro 안내는 뜨지 않고, 휴지통 알림이 그대로 보인다 (F1-B)
    expect(find.text('Mehh Pro'), findsNothing);
    expect(find.textContaining('휴지통을 비우면 그만큼 공간이 생겨요'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'✓ [0-9]+장 · [0-9.]+(KB|MB|GB|B) 휴지통으로')),
      findsOneWidget,
    );
    final stats = PickStats.of(picks);
    expect(stats.suggested, 2);
    expect(stats.accepted, 1);
    expect(stats.added, 0);
    expect(stats.byTag['blurry'], (1, 1));
    expect(stats.byTag['burst'], (0, 1));
    expect(container.read(proProvider).value!.freeLeft(now), 2);
    expect(await container.read(proProvider.notifier).unlock(day.id), isTrue);
    expect(container.read(proProvider).value!.freeLeft(now), 2);
    await flush(tester);
  });

  testWidgets('무료 묶음을 다 쓴 뒤 Pro를 사면 다시 누르지 않아도 추천이 X로 들어간다', (tester) async {
    final day = DayGroup(
      id: 'day-p0',
      kind: DayGroupKind.day,
      photos: burstPhotos,
    );
    final now = DateTime.now();
    await pump(
      tester,
      SortScreen(kind: SortKind.day, group: day),
      vault: MemoryProVault(
        ProState(freeMonth: monthKey(now), freeUsed: freeGroupsPerMonth),
      ),
      extra: [realPlan(paid)],
    );
    await tester.tap(find.text('추천 보기 · 2장'));
    await tester.pumpAndSettle();
    expect(find.text('Mehh Pro'), findsOneWidget);
    expect(
      find.textContaining('0개 · ', findRichText: true),
      findsOneWidget,
    ); // 왜 Pro 안내인지
    await tester.tap(find.text('평생 이용권'));
    await tester.pumpAndSettle();
    expect(find.text('Mehh Pro'), findsNothing); // 사면 시트가 닫힌다
    expect(find.text('2장 휴지통으로'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('잠긴 묶음도 연속 컷을 전부 보내면 "장면이 하나도 안 남아요"를 묻는다', (tester) async {
    // p0·p1이 10초 간격 비슷한 연속 컷, p1은 흔들림 → 추천이 있어서 잠긴 묶음
    final burst = [
      PhotoMeta(
        id: 'p0',
        takenAt: DateTime(2026, 9, 1, 10),
        width: 100,
        height: 100,
      ),
      PhotoMeta(
        id: 'p1',
        takenAt: DateTime(2026, 9, 1, 10, 0, 10),
        width: 100,
        height: 100,
      ),
    ];
    final day = DayGroup(id: 'day-b', kind: DayGroupKind.day, photos: burst);
    final features = {
      'p0': const PhotoFeatures(
        id: 'p0',
        hashHi: 1,
        hashLo: 2,
        sharpness: 500,
        brightness: 120,
      ),
      'p1': const PhotoFeatures(
        id: 'p1',
        hashHi: 1,
        hashLo: 2,
        sharpness: 5,
        brightness: 120,
      ),
    };
    await pump(
      tester,
      SortScreen(kind: SortKind.day, group: day),
      extra: [
        groupPlanProvider.overrideWith(
          (ref, g) => planGroup(
            g.photos,
            features,
            ref.watch(decisionsProvider).value ?? const {},
          ),
        ),
      ],
    );
    expect(find.text('추천 보기 · 1장'), findsOneWidget); // 잠김
    await tester.tap(find.text('전체 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2장 휴지통으로'));
    await tester.pumpAndSettle();
    expect(find.text('1개 장면은 사진이 하나도 안 남아요'), findsOneWidget);
    await tester.tap(find.text('다시 볼게요'));
    await tester.pumpAndSettle();
    await flush(tester);
  });

  test('비공개 테스트 동안(closedTestFree)은 그날의 묶음이 코인 없이 열려 있고 Pro 안내도 없다', () async {
    final c = ProviderContainer(
      overrides: [
        proVaultProvider.overrideWithValue(MemoryProVault()),
        billingProvider.overrideWithValue(DemoBilling(korean: true)),
        storeProvider.overrideWithValue(MemoryStore()),
      ],
    );
    addTearDown(c.dispose);
    final day = DayGroup(id: 'd', kind: DayGroupKind.day, photos: burstPhotos);
    await c.read(proProvider.future);
    expect(c.read(unlockedProvider(day)), isTrue);
    expect(await c.read(proProvider.notifier).canNudge(), isFalse);
  });

  test('무료 묶음은 매달 3개, 다음 달에 다시 채워지고, Pro면 모두 열림', () async {
    final vault = MemoryProVault();
    final billing = DemoBilling(korean: true);
    final c = ProviderContainer(
      overrides: [
        closedTestFreeProvider.overrideWithValue(false),
        proVaultProvider.overrideWithValue(vault),
        billingProvider.overrideWithValue(billing),
      ],
    );
    addTearDown(c.dispose);
    final pro = c.read(proProvider.notifier);
    final oct = DateTime(2026, 10, 21);
    await c.read(proProvider.future);
    for (var i = 0; i < freeGroupsPerMonth; i++) {
      expect(await pro.unlock('g$i', now: oct), isTrue);
    }
    expect(await pro.canNudge(now: DateTime(2026, 9, 1)), isFalse); // 무료가 남은 달
    expect(await pro.canNudge(now: oct), isTrue); // 다 쓴 달에만 Pro 안내
    expect(await pro.unlock('g9', now: oct), isFalse);
    expect(await pro.unlock('g0', now: oct), isTrue); // 이미 연 묶음
    expect(await pro.unlock('g9', now: DateTime(2026, 11, 1)), isTrue);
    expect(nextFreeReset(oct), DateTime(2026, 11, 1));
    expect(nextFreeReset(DateTime(2026, 12, 15)), DateTime(2027, 1, 1));

    final offers = await billing.offers();
    expect(offers.first.plan, Plan.lifetime);
    expect(offers.first.price, '₩12,900');
    await billing.buy(offers.first);
    expect(c.read(proProvider).value!.pro, isTrue);
    expect(await pro.unlock('anything', now: oct), isTrue);
    expect(await pro.takeNudge(), isFalse); // Pro면 안내 안 띄움
    expect(vault.value.lifetime, isTrue);
  });

  test('무료로 연 묶음은 다시 묶여 id가 바뀌어도 열려 있다 (첫 사진을 빼거나 둘로 나뉘어도)', () async {
    final c = ProviderContainer(
      overrides: [
        closedTestFreeProvider.overrideWithValue(false),
        proVaultProvider.overrideWithValue(MemoryProVault()),
        billingProvider.overrideWithValue(DemoBilling(korean: true)),
      ],
    );
    addTearDown(c.dispose);
    await c.read(proProvider.future);
    final opened = DayGroup(
      id: 'day-p0',
      kind: DayGroupKind.day,
      photos: photos,
    );
    expect(
      await c
          .read(proProvider.notifier)
          .unlock(opened.id, photoIds: photos.map((p) => p.id)),
      isTrue,
    );
    // 맨 앞 사진을 휴지통으로 보내 id가 바뀜
    final rest = DayGroup(
      id: 'day-p1',
      kind: DayGroupKind.day,
      photos: photos.sublist(1),
    );
    expect(c.read(unlockedProvider(rest)), isTrue);
    // 위치를 읽어 둘로 나뉨
    final a = DayGroup(
      id: 'day-p0',
      kind: DayGroupKind.day,
      photos: photos.sublist(0, 2),
    );
    final b = DayGroup(
      id: 'day-p2',
      kind: DayGroupKind.day,
      photos: photos.sublist(2),
    );
    expect(c.read(unlockedProvider(a)), isTrue);
    expect(c.read(unlockedProvider(b)), isTrue);
    // 처음 보는 사진만 있는 묶음은 닫혀 있다
    final other = DayGroup(
      id: 'day-x',
      kind: DayGroupKind.day,
      photos: [
        PhotoMeta(id: 'x', takenAt: DateTime(2026, 1, 1), width: 1, height: 1),
      ],
    );
    expect(c.read(unlockedProvider(other)), isFalse);
    // 옛 기록(묶음 id만 있는 것)도 계속 인정
    expect(const ProState(unlocked: {'old'}).isOpen('old'), isTrue);
    expect(c.read(proProvider).value!.freeLeft(DateTime.now()), 2); // 한 번만 씀
  });

  testWidgets('Pro일 때 정리 화면에서 [추천 보기]로 본 묶음은 1년권이 끝나도 열려 있다', (tester) async {
    final billing = DemoBilling(korean: true)..owned.add(Plan.yearly);
    final day = DayGroup(id: 'day-p0', kind: DayGroupKind.day, photos: photos);
    await pump(
      tester,
      SortScreen(kind: SortKind.day, group: day),
      vault: MemoryProVault(const ProState(yearly: true)),
      billing: billing,
      extra: [
        realPlan(darkOn({'p1'})),
      ],
    );
    await tester.tap(find.text('추천 보기 · 1장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('코인'), findsNothing); // Pro는 무료를 안 쓴다
    final c = ProviderScope.containerOf(
      tester.element(find.byType(SortScreen)),
    );
    billing.owned.clear(); // 1년권 끝남
    await c.read(proProvider.notifier).restore(quiet: true);
    expect(c.read(proProvider).value!.pro, isFalse);
    expect(c.read(unlockedProvider(day)), isTrue);
    expect(c.read(proProvider).value!.freeLeft(DateTime.now()), 3);
    await flush(tester);
  });

  test('Pro일 때 연 묶음은 1년 이용권이 끝나도 열려 있다', () async {
    final billing = DemoBilling(korean: true)..owned.add(Plan.yearly);
    final c = ProviderContainer(
      overrides: [
        closedTestFreeProvider.overrideWithValue(false),
        proVaultProvider.overrideWithValue(
          MemoryProVault(const ProState(yearly: true)),
        ),
        billingProvider.overrideWithValue(billing),
      ],
    );
    addTearDown(c.dispose);
    await c.read(proProvider.future);
    await c.read(proProvider.notifier).restore(quiet: true); // 아직 1년권 있음
    expect(c.read(proProvider).value!.pro, isTrue);
    final g = DayGroup(id: 'day-p0', kind: DayGroupKind.day, photos: photos);
    await c
        .read(proProvider.notifier)
        .unlock(g.id, photoIds: photos.map((p) => p.id));
    billing.owned.clear(); // 1년권 끝남
    await c.read(proProvider.notifier).restore(quiet: true);
    expect(c.read(proProvider).value!.pro, isFalse);
    expect(c.read(unlockedProvider(g)), isTrue);
    expect(c.read(proProvider).value!.freeLeft(DateTime.now()), 3); // 무료는 안 씀
  });

  test('1년 이용권이 끝나면 한 번 알린다 (평생권이 있으면 알리지 않는다)', () async {
    final c = ProviderContainer(
      overrides: [
        closedTestFreeProvider.overrideWithValue(false),
        proVaultProvider.overrideWithValue(
          MemoryProVault(const ProState(yearly: true)),
        ),
        billingProvider.overrideWithValue(DemoBilling(korean: true)),
      ],
    );
    addTearDown(c.dispose);
    await c.read(proProvider.future);
    await c.read(proProvider.notifier).restore(quiet: true);
    expect(c.read(proProvider).value!.pro, isFalse);
    expect(c.read(yearlyEndedProvider), isTrue);
  });

  test('다시 열 때: 10분이 안 지났으면 그대로, 지났으면 로딩 없이 새로 불러온다', () async {
    final lib = _CountingLibrary();
    final c = ProviderContainer(
      overrides: [
        closedTestFreeProvider.overrideWithValue(false),
        photoLibraryProvider.overrideWithValue(lib),
        storeProvider.overrideWithValue(MemoryStore()),
      ],
    );
    addTearDown(c.dispose);
    await c.read(libraryProvider.future);
    expect(lib.loads, 1);
    final n = c.read(libraryProvider.notifier);
    await n.refreshIfStale(const Duration(minutes: 10));
    expect(lib.loads, 1);
    await n.refreshIfStale(
      const Duration(minutes: 10),
      now: DateTime.now().add(const Duration(minutes: 11)),
    );
    expect(lib.loads, 2);
    expect(c.read(libraryProvider).hasValue, isTrue); // 로딩으로 바뀌지 않음
  });

  test('Pro가 켜지는 순간(복원 포함) 신호가 한 번 올라간다', () async {
    final billing = DemoBilling(korean: true)..owned.add(Plan.lifetime);
    final c = ProviderContainer(
      overrides: [
        closedTestFreeProvider.overrideWithValue(false),
        proVaultProvider.overrideWithValue(MemoryProVault()),
        billingProvider.overrideWithValue(billing),
      ],
    );
    addTearDown(c.dispose);
    await c.read(proProvider.future);
    expect(c.read(proStartedProvider), isFalse);
    await c.read(proProvider.notifier).restore(quiet: true); // 새 폰 조용한 복원
    expect(c.read(proProvider).value!.pro, isTrue);
    expect(c.read(proStartedProvider), isTrue);
  });

  test('달이 바뀌어 무료 묶음이 다시 생기면 신호 한 번 (같은 달에 다시 확인하면 없음)', () async {
    final c = ProviderContainer(
      overrides: [
        closedTestFreeProvider.overrideWithValue(false),
        proVaultProvider.overrideWithValue(
          MemoryProVault(const ProState(freeMonth: '2026-10', freeUsed: 3)),
        ),
        billingProvider.overrideWithValue(DemoBilling(korean: true)),
      ],
    );
    addTearDown(c.dispose);
    await c.read(proProvider.future);
    final pro = c.read(proProvider.notifier);
    final nov = DateTime(2026, 11, 2);
    await pro.checkMonth(now: nov);
    expect(c.read(freeRefilledProvider), isTrue);
    expect(c.read(proProvider).value!.freeLeft(nov), 3);
    c.read(freeRefilledProvider.notifier).clear();
    await pro.checkMonth(now: nov);
    expect(c.read(freeRefilledProvider), isFalse);
  });

  test('구매 복원: 1년 이용권이 끝나면 꺼지고, 평생권은 남는다', () async {
    final vault = MemoryProVault(const ProState(lifetime: true, yearly: true));
    final c = ProviderContainer(
      overrides: [
        closedTestFreeProvider.overrideWithValue(false),
        proVaultProvider.overrideWithValue(vault),
        billingProvider.overrideWithValue(DemoBilling(korean: true)),
      ],
    );
    addTearDown(c.dispose);
    await c.read(proProvider.future);
    expect(await c.read(proProvider.notifier).restore(), isFalse);
    expect(vault.value.yearly, isFalse);
    expect(vault.value.lifetime, isTrue);
  });

  testWidgets('Cortex: [Cortex로] → 받았다는 신호 → "받았어요 · 휴지통으로 보낼까요?" → 휴지통으로', (
    tester,
  ) async {
    final shots = DayGroup(
      id: 'shots',
      kind: DayGroupKind.screenshots,
      photos: photos,
    );
    final handoff = _FakeHandoff();
    await pump(
      tester,
      SortScreen(kind: SortKind.screenshots, group: shots),
      extra: [
        cortexInstalledProvider.overrideWith((ref) async => true),
        handoffProvider.overrideWithValue(handoff),
      ],
    );
    expect(find.text('Cortex로'), findsNothing); // 고르기 전엔 없다
    await tester.tap(find.byType(XToggle).at(0));
    await tester.tap(find.byType(XToggle).at(1));
    await tester.pumpAndSettle();

    expect(find.text('2장 휴지통으로'), findsOneWidget); // 그냥 지울 수도 있다
    // [취소]면 보내지 않는다
    await tester.tap(find.text('Cortex로'));
    await tester.pumpAndSettle();
    expect(find.text('2장을 Cortex로 보낼까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(handoff.sent, isEmpty);
    await sendCortex(tester);
    expect(handoff.sent.length, 2);
    expect(find.textContaining('  4장'), findsOneWidget); // 아직 휴지통으로 안 감
    // 기다리는 동안 버튼은 잠그지 않는다
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('2장 휴지통으로'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );

    // 신호 없이 돌아오면 묻지도 옮기지도 않는다. 사진에 "Cortex로 보냄"
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('  4장'), findsOneWidget);
    expect(find.textContaining('받았다는 신호가 없어서 휴지통으로 보내지 않았어요'), findsOneWidget);
    expect(find.text('Cortex로 보냄'), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 6)); // 알림이 사라지게
    await tester.pumpAndSettle();

    // 보낸 것보다 적게 받았다고 알려 오면 묻지 않는다
    await sendCortex(tester);
    handoff.saved.add(const CortexSaved(1, null));
    await tester.pumpAndSettle();
    expect(find.textContaining('1장만 받았다고'), findsOneWidget);
    expect(find.textContaining('받았어요'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    // 받은 사진 목록이 오면 그 사진만 묻는다. [나중에]면 X 그대로, "Cortex에 있음"
    await sendCortex(tester);
    final first = handoff.sent.first;
    handoff.sent.clear();
    handoff.saved.add(CortexSaved(1, {first}));
    await tester.pumpAndSettle();
    expect(find.text('✓ Cortex가 1장 받았어요'), findsOneWidget);
    expect(find.textContaining('앱을 닫아도 돼요'), findsOneWidget);
    expect(find.textContaining('받지 못한 1장은 그대로'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    expect(find.textContaining('  4장'), findsOneWidget);
    expect(find.text('Cortex에 있음'), findsOneWidget);
    expect(find.text('Cortex로 보냄'), findsOneWidget);

    // 장수만 와도 다 받았으면 묻고, [휴지통으로]면 보낸다 (장수·용량 알림)
    await sendCortex(tester);
    handoff.saved.add(const CortexSaved(2, null));
    await tester.pumpAndSettle();
    expect(find.text('✓ Cortex가 2장 받았어요'), findsOneWidget);
    await tester.tap(find.text('휴지통으로'));
    await tester.pumpAndSettle();
    expect(find.textContaining('  2장'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'✓ 2장 · .+ 휴지통으로 보냈어요')),
      findsOneWidget,
    );
    expect(find.text('Cortex에 있음'), findsNothing);
    expect(find.text('Cortex로 보냄'), findsNothing);
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();

    // 늦게 온 신호: 신호 없이 돌아온 뒤에 "받았어요"가 와도 묻는다
    await tester.tap(find.byType(XToggle).at(0));
    await tester.pumpAndSettle();
    handoff.sent.clear();
    await sendCortex(tester);
    final late = handoff.sent.first;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Cortex로 보냄'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    handoff.saved.add(CortexSaved(1, {late}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('휴지통으로'));
    await tester.pumpAndSettle();
    expect(find.textContaining('  1장'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('Cortex: 기다리는 동안 또 보내도 먼저 보낸 것의 신호는 그것만 묻는다 (S-3)', (
    tester,
  ) async {
    final shots = DayGroup(
      id: 'shots',
      kind: DayGroupKind.screenshots,
      photos: photos,
    );
    final handoff = _FakeHandoff();
    await pump(
      tester,
      SortScreen(kind: SortKind.screenshots, group: shots),
      extra: [
        cortexInstalledProvider.overrideWith((ref) async => true),
        handoffProvider.overrideWithValue(handoff),
      ],
    );
    // 첫 묶음: 1장
    await tester.tap(find.byType(XToggle).at(0));
    await tester.pumpAndSettle();
    await sendCortex(tester);
    final first = [...handoff.sent];
    handoff.sent.clear();
    // 둘째 묶음: 다른 2장 (첫 장은 X를 꺼서 빠진다)
    await tester.tap(find.byType(XToggle).at(0));
    await tester.tap(find.byType(XToggle).at(1));
    await tester.tap(find.byType(XToggle).at(2));
    await tester.pumpAndSettle();
    await sendCortex(tester);
    final second = [...handoff.sent];
    expect(second.length, 2);
    expect(find.text('Cortex로 보냄'), findsNWidgets(3));

    // 첫 묶음의 신호: 그 1장만 묻고, "0장" 알림도 "받지 못한" 줄도 없다
    handoff.saved.add(CortexSaved(1, first.toSet()));
    await tester.pumpAndSettle();
    expect(find.text('✓ Cortex가 1장 받았어요'), findsOneWidget);
    expect(find.textContaining('받지 못한'), findsNothing);
    expect(find.textContaining('0장만'), findsNothing);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    // 둘째 묶음의 신호도 그대로 받는다
    handoff.saved.add(CortexSaved(2, second.toSet()));
    await tester.pumpAndSettle();
    expect(find.text('✓ Cortex가 2장 받았어요'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    expect(find.text('Cortex로 보냄'), findsNothing);
    expect(find.text('Cortex에 있음'), findsNWidgets(3));
    await flush(tester);
  });

  testWidgets('Cortex: 그날의 묶음에서 Cortex로 보내고 [휴지통으로]여도 정확도 기록이 남는다 (S-2)', (
    tester,
  ) async {
    final day = DayGroup(
      id: 'day-p0',
      kind: DayGroupKind.day,
      photos: burstPhotos,
    );
    final handoff = _FakeHandoff();
    final store = MemoryStore();
    await pump(
      tester,
      SortScreen(kind: SortKind.day, group: day),
      store: store,
      extra: [
        realPlan(paid),
        cortexInstalledProvider.overrideWith((ref) async => true),
        handoffProvider.overrideWithValue(handoff),
      ],
    );
    await openLocked(tester, '추천 보기 · 2장');
    await sendCortex(tester);
    handoff.saved.add(CortexSaved(handoff.sent.length, null));
    await tester.pumpAndSettle();
    await tester.tap(find.text('휴지통으로'));
    await tester.pumpAndSettle();
    final picks = await store.loadPicks();
    expect(picks.where((p) => p.kind == 'day'), isNotEmpty);
    expect(picks.where((p) => p.sent), isNotEmpty);
    await flush(tester);
  });

  testWidgets('Cortex: 캡처가 아닌 낱장 사진에서도 [휴지통으로] 옆에 [Cortex로]', (tester) async {
    await pump(
      tester,
      SortScreen(kind: SortKind.singles, group: group),
      extra: [cortexInstalledProvider.overrideWith((ref) async => true)],
    );
    await tester.tap(find.byType(XToggle).at(0));
    await tester.pumpAndSettle();
    expect(find.text('Cortex로'), findsOneWidget);
    await flush(tester);
  });
}

class _FakeHandoff extends Handoff {
  _FakeHandoff({this.installed = true});
  bool installed;
  final sent = <String>[];

  @override
  Future<bool> cortexInstalled() async => installed;
  final saved = StreamController<CortexSaved>.broadcast();

  @override
  Stream<CortexSaved> get cortexSaved => saved.stream;

  @override
  Future<SendResult> sendManyToCortex(List<String> photoIds) async {
    sent.addAll(photoIds);
    return SendResult.ok;
  }
}

class _NeverAnalyzedLibrary extends DemoPhotoLibrary {
  @override
  Future<void> analyze(
    List<PhotoMeta> metas, {
    required Future<void> Function(List<PhotoFeatures>) onBatch,
    bool Function()? cancelled,
  }) => Completer<void>().future;
}

class _CountingLibrary extends DemoPhotoLibrary {
  var loads = 0;

  @override
  Future<List<PhotoMeta>> loadAll() {
    loads++;
    return super.loadAll();
  }
}

class _FixedAnalysis extends AnalysisNotifier {
  _FixedAnalysis(this.features);
  final Map<String, PhotoFeatures> features;

  @override
  AnalysisState build() =>
      AnalysisState(features: features, total: features.length, done: true);
}

class _FixedLibrary extends LibraryNotifier {
  _FixedLibrary(this.value);
  final LibraryState value;

  @override
  Future<LibraryState> build() async => value;

  // 보낸 사진만 빼고 묶음은 그대로 (실제는 다시 묶지만 테스트에선 고정)
  @override
  void removePhotos(Set<String> ids) {
    final now = state.value ?? value;
    state = AsyncData(
      LibraryState(
        photos: [
          for (final p in now.photos)
            if (!ids.contains(p.id)) p,
        ],
        groups: [
          for (final g in now.groups)
            DayGroup(
              id: g.id,
              kind: g.kind,
              photos: [
                for (final p in g.photos)
                  if (!ids.contains(p.id)) p,
              ],
            ),
        ],
      ),
    );
  }
}
