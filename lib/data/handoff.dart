import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 캡처를 받아 정리해 주는 Sophie의 다른 앱. 스토어 출시 때 실제 패키지 이름으로 바꾼다.
const cortexPackage = 'com.anonymous.cortex';

enum SendResult { ok, unsupported, failed }

/// Mehh → 다른 앱으로 사진 넘기기 (사용자가 버튼을 누를 때만).
/// 일반 공유시트는 쓰지 않는다: 캡처는 Cortex로만 보낸다.
class Handoff {
  Handoff() {
    if (!kIsWeb) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'cortexSaved') {
          _saved.add(call.arguments as int? ?? 0);
        }
      });
    }
  }

  static const _channel = MethodChannel('mehh/handoff');
  final _saved = StreamController<int>.broadcast();

  /// Cortex가 "저장 완료"를 알려 왔다 (mehh://cortex-saved?count=N). 값은 저장한 장수.
  /// 이 신호가 와야 보낸 캡처를 휴지통으로 옮긴다 (2026-10-22 Sophie C2-A)
  Stream<int> get cortexSaved => _saved.stream;

  /// Cortex가 이 폰에 설치돼 있을 때만 버튼을 보여 준다.
  /// (설치 안 된 경우 스토어로 안내하는 건 나라별 출시 확인 후 5단계에서)
  Future<bool> cortexInstalled() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isInstalled', {
            'package': cortexPackage,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 여러 장을 한 번에 Cortex로. Cortex가 여러 장 받기를 아직 못 하면 [SendResult.unsupported].
  Future<SendResult> sendManyToCortex(List<String> photoIds) async {
    try {
      final r = await _channel.invokeMethod<String>('sendImages', {
        'package': cortexPackage,
        'ids': photoIds,
      });
      return switch (r) {
        'ok' => SendResult.ok,
        'unsupported' => SendResult.unsupported,
        _ => SendResult.failed,
      };
    } catch (_) {
      return SendResult.failed;
    }
  }

  Future<bool> sendToCortex(String photoId) async {
    try {
      return await _channel.invokeMethod<bool>('sendImage', {
            'package': cortexPackage,
            'id': photoId,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
