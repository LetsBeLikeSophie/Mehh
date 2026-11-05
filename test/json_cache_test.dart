import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/data/crash_reports.dart';
import 'package:mehh/data/json_cache.dart';

/// 저장 공간이 꽉 찬 폰에서 위치 캐시를 못 써도 위치 읽기가 멈추지 않는다 (리뷰 11-05 S-2)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mehh_cache');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('쓰기가 실패해도 던지지 않고 .tmp를 남기지 않으며, 오류 기록엔 종류만 (S-2 11-05)', () async {
    // 그 자리에 폴더가 있어 바꿔 넣기(rename)가 실패한다
    Directory('${dir.path}/locations.json').createSync();
    final sent = <String>[];
    final before = FlutterError.onError;
    catchCrashes((type, stack) => sent.add(type));
    FlutterError.onError = before;

    await JsonCache('locations.json').write({'a': null});

    expect(File('${dir.path}/locations.json.tmp').existsSync(), isFalse);
    expect(sent, hasLength(1));
    expect(sent.single.contains(dir.path), isFalse);
  });

  test('쓰기가 되면 그대로 읽힌다', () async {
    await JsonCache('locations.json').write({'a': 1});
    expect(await JsonCache('locations.json').read(), {'a': 1});
  });
}
