import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/data/crash_reports.dart';
import 'package:mehh/l10n/app_localizations.dart';

void main() {
  const path = '/storage/emulated/0/DCIM/Camera/내 사진.jpg';

  test('첫 화면 약속은 오류 기록을 빼고 사진과 정리 기록만 말한다 (리뷰 11-02 S-1)', () {
    expect(lookupL10n(const Locale('ko')).promiseLocal, contains('정리 기록'));
    expect(
      lookupL10n(const Locale('en')).promiseLocal,
      contains('cleanup records'),
    );
  });

  test('화면 오류: 종류와 코드 위치만 넘기고 오류 글의 파일 경로는 넘기지 않는다 (R1-B)', () {
    final before = FlutterError.onError;
    final beforeDispatcher = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = before;
      PlatformDispatcher.instance.onError = beforeDispatcher;
    });
    final sent = <String>[];
    FlutterError.onError = (_) {};
    catchCrashes((type, stack) => sent.add(type));

    FlutterError.onError!(
      FlutterErrorDetails(
        exception: const FileSystemLikeError(path),
        stack: StackTrace.current,
      ),
    );

    expect(sent, ['FileSystemLikeError']);
  });

  test('비동기 오류: 종류만 넘기고 오류 글의 파일 경로는 넘기지 않는다 (R1-B)', () {
    final before = FlutterError.onError;
    final beforeDispatcher = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = before;
      PlatformDispatcher.instance.onError = beforeDispatcher;
    });
    final sent = <String>[];
    catchCrashes((type, stack) => sent.add(type));

    PlatformDispatcher.instance.onError!(
      const FileSystemLikeError(path),
      StackTrace.current,
    );

    expect(sent, ['FileSystemLikeError']);
  });
}

class FileSystemLikeError implements Exception {
  const FileSystemLikeError(this.path);
  final String path;

  @override
  String toString() => 'Cannot open $path';
}
