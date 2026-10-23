// 폰 없이 화면을 이미지로 뽑는 도구 (웹 미리보기와 같은 샘플 데이터).
// 실행: flutter test tool/capture/capture_test.dart --update-goldens
// 결과: tool/capture/goldens/*.png (git에 올리지 않는다)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/data/billing.dart';
import 'package:mehh/data/demo.dart';
import 'package:mehh/data/photo_library.dart';
import 'package:mehh/data/pro.dart';
import 'package:mehh/data/store.dart';
import 'package:mehh/models/decision.dart';
import 'package:mehh/l10n/l10n.dart';
import 'package:mehh/models/day_group.dart';
import 'package:mehh/models/photo_meta.dart';
import 'package:mehh/models/pick.dart';
import 'package:mehh/providers.dart';
import 'package:mehh/theme.dart';
import 'package:mehh/ui/accuracy_screen.dart';
import 'package:mehh/ui/home_tab.dart';
import 'package:mehh/ui/pro_sheet.dart';
import 'package:mehh/ui/settings_screen.dart';
import 'package:mehh/ui/sort_screen.dart';

Future<void> _loadFonts() async {
  final family = FontLoader(mehhFontFamily);
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('fonts/MehhSansKR-$w.ttf').readAsBytesSync();
    family.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await family.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final f = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await f.load();
  }
}

void main() {
  final shotKey = GlobalKey();
  final navKey = GlobalKey<NavigatorState>();

  Future<ProviderContainer> start(
    WidgetTester tester, {
    ProState pro = const ProState(),
    MemoryStore? store,
  }) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryProvider.overrideWithValue(
            DemoPhotoLibrary() as PhotoLibrary,
          ),
          storeProvider.overrideWithValue(store ?? MemoryStore()),
          proVaultProvider.overrideWithValue(MemoryProVault(pro)),
          billingProvider.overrideWithValue(DemoBilling(korean: true)),
        ],
        child: RepaintBoundary(
          key: shotKey,
          child: MaterialApp(
            navigatorKey: navKey,
            debugShowCheckedModeBanner: false,
            theme: buildMehhTheme(),
            locale: const Locale('ko'),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            home: const Scaffold(body: HomeTab()),
          ),
        ),
      ),
    );
    // 샘플 분석이 끝날 때까지
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    return ProviderScope.containerOf(tester.element(find.byType(HomeTab)));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(shotKey),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  Future<void> open(WidgetTester tester, Widget screen) async {
    navKey.currentState!.push(MaterialPageRoute(builder: (_) => screen));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  DayGroup firstDayWithPicks(ProviderContainer c) {
    final groups = c.read(libraryProvider).value!.groups;
    return groups.firstWhere(
      (g) =>
          g.kind == DayGroupKind.day &&
          c.read(groupPlanProvider(g)).trash.length >= 3,
    );
  }

  DayGroup kindGroup(ProviderContainer c, DayGroupKind kind) =>
      c.read(libraryProvider).value!.groups.firstWhere((g) => g.kind == kind);

  setUpAll(_loadFonts);

  testWidgets('01 홈', (tester) async {
    await start(tester);
    await shot(tester, '01_home');
  });

  testWidgets('01b 홈 비운 양 막대', (tester) async {
    final store = MemoryStore()
      ..freed[monthKey(DateTime.now())] = 34 * 1024 * 1024;
    final c = await start(tester, store: store);
    final ids = [
      for (final p in c.read(libraryProvider).value!.photos.take(12)) p.id,
    ];
    await c.read(decisionsProvider.notifier).set(ids, DecisionState.toTrash);
    await tester.pumpAndSettle();
    await shot(tester, '01b_home_bar');
  });

  testWidgets('02 그날의 묶음 (잠김, 누르기 전)', (tester) async {
    final c = await start(tester);
    await open(
      tester,
      SortScreen(kind: SortKind.day, group: firstDayWithPicks(c)),
    );
    await shot(tester, '02_day_locked');
  });

  testWidgets('03 그날의 묶음 ([추천 보기] 누른 뒤)', (tester) async {
    final c = await start(tester);
    await open(
      tester,
      SortScreen(kind: SortKind.day, group: firstDayWithPicks(c)),
    );
    await tester.tap(find.textContaining('추천 보기'));
    await tester.pump(const Duration(seconds: 1));
    await shot(tester, '03a_day_free_note');
    await tester.pump(const Duration(seconds: 6)); // 알림이 사라지게
    await shot(tester, '03b_day_picks');
  });

  testWidgets('04 무료 다 쓴 잠긴 묶음', (tester) async {
    final now = DateTime.now();
    final c = await start(
      tester,
      pro: ProState(freeMonth: monthKey(now), freeUsed: freeGroupsPerMonth),
    );
    await open(
      tester,
      SortScreen(kind: SortKind.day, group: firstDayWithPicks(c)),
    );
    await shot(tester, '04_day_no_free');
  });

  testWidgets('05 캡처 ([추천 보기] 누른 뒤, 절반은 200일 전 캡처로)', (tester) async {
    final c = await start(tester);
    final shots = kindGroup(c, DayGroupKind.screenshots);
    final aged = DayGroup(
      id: shots.id,
      kind: DayGroupKind.screenshots,
      photos: [
        for (final (i, p) in shots.photos.indexed)
          PhotoMeta(
            id: p.id,
            takenAt: i.isEven
                ? p.takenAt.subtract(const Duration(days: 200))
                : p.takenAt,
            width: p.width,
            height: p.height,
            isScreenshot: true,
          ),
      ]..sort((a, b) => a.takenAt.compareTo(b.takenAt)),
    );
    await open(tester, SortScreen(kind: SortKind.screenshots, group: aged));
    await shot(tester, '05a_screenshots_before');
    await tester.tap(find.textContaining('추천 보기'));
    await tester.pump(const Duration(seconds: 1));
    // 오래된 캡처는 아래쪽(최신이 위)이라 내려서 찍는다
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await shot(tester, '05b_screenshots_picks');
  });

  testWidgets('05c 캡처 + Cortex (고르면 [휴지통으로] 옆 [Cortex로])', (tester) async {
    final c = await start(tester);
    await open(
      tester,
      ProviderScope(
        // Cortex가 깔린 폰처럼
        overrides: [cortexInstalledProvider.overrideWith((ref) async => true)],
        child: SortScreen(
          kind: SortKind.screenshots,
          group: kindGroup(c, DayGroupKind.screenshots),
        ),
      ),
    );
    await tester.tap(find.text('전체 선택'));
    await shot(tester, '05c_screenshots_cortex');
    await tester.tap(find.text('Cortex로'));
    await shot(tester, '05d_cortex_confirm');
  });

  testWidgets('02b 잠긴 묶음 [추천 보기] 누름 → 무료 묶음 확인', (tester) async {
    final c = await start(tester);
    await open(
      tester,
      SortScreen(kind: SortKind.day, group: firstDayWithPicks(c)),
    );
    await tester.tap(find.textContaining('추천 보기'));
    await shot(tester, '02b_day_confirm');
  });

  testWidgets('06 Pro 안내', (tester) async {
    await start(tester);
    showProSheet(navKey.currentContext!);
    await tester.pump(const Duration(seconds: 1));
    await shot(tester, '06_pro_sheet');
  });

  testWidgets('06b Pro 안내 (무료를 다 쓴 달)', (tester) async {
    final now = DateTime.now();
    await start(
      tester,
      pro: ProState(freeMonth: monthKey(now), freeUsed: freeGroupsPerMonth),
    );
    showProSheet(navKey.currentContext!);
    await tester.pump(const Duration(seconds: 1));
    await shot(tester, '06b_pro_sheet_no_free');
  });

  testWidgets('07 숨은 추천 정확도 화면 (예시 기록)', (tester) async {
    final store = MemoryStore();
    final at = DateTime(2026, 10, 22);
    PickRecord r(String kind, String tag, bool sent) =>
        PickRecord(at: at, kind: kind, tag: tag, suggested: true, sent: sent);
    await store.addPicks([
      for (var i = 0; i < 30; i++) r('day', 'burst', i < 25),
      for (var i = 0; i < 22; i++) r('day', 'blurry', i < 8),
      for (var i = 0; i < 70; i++) r('screenshots', 'oldShot', i < 66),
      for (var i = 0; i < 6; i++) r('singles', 'junk', true),
    ]);
    await start(tester, store: store);
    await open(tester, const AccuracyScreen());
    await shot(tester, '07_accuracy');
  });

  testWidgets('08 설정', (tester) async {
    await start(tester);
    await open(tester, const SettingsScreen());
    await shot(tester, '08_settings');
  });
}
