import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 갤러리 휴지통을 열었을 때 결과
enum TrashOpen {
  /// 휴지통 화면을 바로 열었다
  trash,

  /// 갤러리 앱만 열었다 (휴지통은 갤러리 메뉴에서)
  gallery,

  /// 열 수 있는 갤러리가 없다
  none,
}

/// 기기 정보 (안드로이드 MainActivity의 mehh/device). 웹·테스트에서는 없음으로 답한다.
class Device {
  static const _channel = MethodChannel('mehh/device');

  /// 사진첩 사진 전체 용량(바이트). 모르면 null
  Future<int?> photoBytes() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<int>('photoBytes');
    } catch (_) {
      return null;
    }
  }

  /// 갤러리 앱의 휴지통 열기 (2026-10-24 Sophie)
  Future<TrashOpen> openTrash() async {
    if (kIsWeb || !Platform.isAndroid) return TrashOpen.none;
    try {
      return switch (await _channel.invokeMethod<String>('openTrash')) {
        'trash' => TrashOpen.trash,
        'gallery' => TrashOpen.gallery,
        _ => TrashOpen.none,
      };
    } catch (_) {
      return TrashOpen.none;
    }
  }
}
