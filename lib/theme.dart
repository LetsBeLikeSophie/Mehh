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
  static const white = Color(0xFFFFFFFF);
}

abstract final class MehhRadius {
  static const card = 12.0;
  static const button = 8.0;
  static const thumb = 6.0;
}

const mehhFontFamily = 'IBM Plex Sans KR';

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
