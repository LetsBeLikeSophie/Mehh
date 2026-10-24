import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 디자인 토큰 (docs/SPEC.md 5장). 흰색·회색·검정만 쓴다.
abstract final class MehhColors {
  static const black = Color(0xFF111111);
  static const text = Color(0xFF37352F);
  static const textMuted = Color(0xFF787774);
  static const surface = Color(0xFFF7F7F5);
  static const tile = Color(0xFFF1F1EF);
  static const border = Color(0xFFE9E9E7);
  static const icon = Color(0xFFACABA9);

  /// 포인트 색: 용량 막대의 "정리 가능·선택" 칸에만 쓴다 (2026-10-24 Sophie B 코랄)
  static const accent = Color(0xFFD85A30);

  /// 검정 카드 위 보조 글자
  static const onBlackMuted = Color(0xFFB4B4B0);
  static const white = Color(0xFFFFFFFF);
}

abstract final class MehhRadius {
  static const card = 12.0;
  static const button = 8.0;
  static const thumb = 6.0;

  /// 홈 목록 대표 사진
  static const tile = 8.0;

  /// 아래 사진 줄의 작은 사진
  static const strip = 4.0;

  /// 작은 배지 ("베스트", 장수 칩)
  static const badge = 4.0;

  /// 사진 위 표시 칩
  static const chip = 6.0;

  /// 크게 보는 사진
  static const photo = 16.0;
}

/// 글자 크기 (SPEC 5장). 화면에 숫자를 직접 쓰지 않는다 (test/style_guard_test.dart).
abstract final class MehhText {
  /// 홈·온보딩 큰 제목
  static const display = 28.0;

  /// 화면 제목
  static const title = 22.0;

  /// 대화상자 제목, 끌 때 뜨는 큰 칩
  static const heading = 18.0;

  /// 카드 제목
  static const lead = 16.0;

  /// 본문, 버튼
  static const body = 15.0;

  /// 보조 본문
  static const bodySmall = 14.0;

  /// 목록 부제, 설명
  static const caption = 13.0;

  /// 섹션 이름, 작은 칩
  static const label = 12.0;

  /// 연도 레일 같은 아주 작은 글자
  static const tiny = 11.0;

  /// 사진 위 배지
  static const micro = 10.0;
}

/// IBM Plex Sans KR을 줄인 글꼴 (OFL 예약 이름 때문에 이름을 바꿈, tool/subset_fonts.py)
const mehhFontFamily = 'Mehh Sans KR';

ThemeData buildMehhTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: mehhFontFamily,
    scaffoldBackgroundColor: MehhColors.white,
    colorScheme: const ColorScheme.light(
      primary: MehhColors.black,
      onPrimary: MehhColors.white,
      surface: MehhColors.white,
      onSurface: MehhColors.text,
      outline: MehhColors.border,
    ),
    splashFactory: NoSplash.splashFactory,
    // 안드로이드에서도 왼쪽 가장자리를 오른쪽으로 밀면 이전 화면으로
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: MehhColors.text,
      displayColor: MehhColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MehhColors.white,
      foregroundColor: MehhColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MehhColors.black,
        foregroundColor: MehhColors.white,
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MehhRadius.button),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MehhColors.text,
        minimumSize: const Size(44, 48),
        side: const BorderSide(color: MehhColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MehhRadius.button),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: MehhColors.tile,
      thickness: 1,
      space: 1,
    ),
  );
}
