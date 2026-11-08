import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 동영상의 찍은 시각 (없으면 null)
typedef VideoDetail = ({DateTime? takenAt});

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

  /// 동영상 id → 파일 크기 (한 번에). 모르면 null
  Future<Map<String, int>?> videoSizes() => _sizes('videoSizes');

  /// 사진 id → 파일 크기 (한 번에). 모르면 null
  Future<Map<String, int>?> imageSizes() => _sizes('imageSizes');

  /// 동영상 id → 찍은 시각. 찍은 시각이 비어 있으면 편집 앱 등이 새로 만든 영상
  /// (2026-11-07 Sophie). 모르면(웹·iOS) null
  Future<Map<String, VideoDetail>?> videoDetails() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final m = await _channel.invokeMethod<Map>('videoDetails');
      return m?.map((k, v) {
        final l = v as List;
        final ms = l[0] as num?;
        return MapEntry(k.toString(), (
          takenAt: ms == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
        ));
      });
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, int>?> _sizes(String method) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final m = await _channel.invokeMethod<Map>(method);
      return m?.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (_) {
      return null;
    }
  }

  /// 동영상 하나를 갤러리(기본 동영상 앱)에서 재생 (2026-10-26 Sophie V3-A). 못 열면 false
  Future<bool> openVideo(String id) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openVideo', {'id': id}) ??
          false;
    } catch (_) {
      return false;
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
