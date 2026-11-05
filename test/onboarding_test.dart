import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mehh/l10n/l10n.dart';
import 'package:mehh/providers.dart';
import 'package:mehh/data/demo.dart';
import 'package:mehh/data/photo_library.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:mehh/theme.dart';
import 'package:mehh/ui/onboarding_screen.dart';

/// 글자를 키운 작은 폰에서도 온보딩의 하나뿐인 버튼을 누를 수 있어야 한다 (UX-93)
void main() {
  // 기본 시험 글꼴은 글자마다 폭이 1em이라 넘침을 부풀린다. 앱 글꼴로 잰다
  setUpAll(() async {
    final family = FontLoader(mehhFontFamily);
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final bytes = File('fonts/MehhSansKR-$w.ttf').readAsBytesSync();
      family.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await family.load();
  });

  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    required double scale,
    required String lang,
    bool cortex = true,
    PhotoLibrary? library,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    // 위 상태 바 24, 아래 3버튼 내비 48
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryProvider.overrideWithValue(library ?? DemoPhotoLibrary()),
          cortexInstalledProvider.overrideWith((ref) async => cortex),
        ],
        child: MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: MaterialApp(
            theme: buildMehhTheme(),
            locale: Locale(lang),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            home: const OnboardingScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const small = Size(360, 800);
  for (final lang in ['ko', 'en']) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        '360×800 · $lang · 글자 ${(scale * 100).round()}%: 넘치지 않고 버튼이 눌린다',
        (tester) async {
          await pump(tester, size: small, scale: scale, lang: lang);
          expect(tester.takeException(), isNull);
          final button = find.byType(FilledButton);
          // 넘칠 때만 스크롤해서 닿는다
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          final rect = tester.getRect(button);
          expect(rect.bottom, lessThanOrEqualTo(small.height - 48));
          expect(rect.top, greaterThanOrEqualTo(24));
          await tester.tap(button);
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('보통 글자·들어가는 화면은 버튼이 맨 아래 그대로, 스크롤되지 않는다', (tester) async {
    await pump(
      tester,
      size: const Size(390, 844),
      scale: 1,
      lang: 'ko',
      cortex: false,
    );
    final rect = tester.getRect(find.byType(FilledButton));
    // 아래 내비 48 + 여백 32 바로 위
    expect(rect.bottom, closeTo(844 - 48 - 32, 0.01));
    final scroll = find.byType(Scrollable);
    if (scroll.evaluate().isNotEmpty) {
      expect(
        tester.state<ScrollableState>(scroll.first).position.maxScrollExtent,
        0,
      );
    }
  });
  for (final lang in ['ko', 'en']) {
    testWidgets('$lang · 360×800 · 글자 130%: 거절하면 버튼 위에 설정 안내 한 줄, 버튼까지 스크롤 (UX-100)', (
      tester,
    ) async {
      final lib = _DenyingLibrary();
      await pump(
        tester,
        size: small,
        scale: 1.3,
        lang: lang,
        library: lib,
      );
      final hint = lang == 'ko'
          ? '설정에서 [권한] → [사진 및 동영상] → [모두 허용]을 눌러 주세요'
          : 'In Settings, tap Permissions → Photos and videos → Allow all';
      expect(find.text(hint), findsNothing);

      final button = find.byType(FilledButton);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(hint), findsOneWidget);
      expect(
        find.text(lang == 'ko' ? '설정에서 허용하기' : 'Allow in Settings'),
        findsOneWidget,
      );

      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final rect = tester.getRect(button);
      expect(rect.bottom, lessThanOrEqualTo(small.height - 48));
      // 안내는 버튼 바로 위
      expect(tester.getRect(find.text(hint)).bottom, lessThan(rect.top));
      await tester.tap(button);
      await tester.pump();
      expect(lib.settingsOpened, 1);
    });
  }
}

class _DenyingLibrary extends DemoPhotoLibrary {
  var settingsOpened = 0;

  @override
  Future<PermissionState> requestPermission() async => PermissionState.denied;

  @override
  Future<void> openSettings() async => settingsOpened++;
}
