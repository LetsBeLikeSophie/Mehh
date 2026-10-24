import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  /// 갤러리 앱 열기 (2026-10-24 Sophie). 열 앱이 없으면 false
  Future<bool> openGallery() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openGallery') ?? false;
    } catch (_) {
      return false;
    }
  }
}
