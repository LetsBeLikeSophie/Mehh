import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// 오류 종류·코드 위치만 보낸다. 오류 글에는 파일 경로·사진 이름이 들 수 있어 보내지 않는다
/// (2026-11-01 Sophie R1-B)
typedef SendCrash = void Function(String type, StackTrace? stack);

/// 앱 안에서 잡히지 않은 오류를 [send]로 넘긴다
void catchCrashes(SendCrash send) {
  final shown = FlutterError.onError;
  FlutterError.onError = (details) {
    shown?.call(details);
    send(details.exception.runtimeType.toString(), details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    send(error.runtimeType.toString(), stack);
    return false;
  };
}

/// 안드로이드 출시 빌드에서만 켠다. 실패해도 앱은 그대로 켜진다
Future<void> startCrashReports() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Firebase.initializeApp();
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode);
    catchCrashes((type, stack) {
      crashlytics
          .recordError(type, stack, printDetails: false)
          .catchError((Object _) {});
    });
  } catch (_) {}
}
