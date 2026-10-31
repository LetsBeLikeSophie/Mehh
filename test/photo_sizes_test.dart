import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/data/photo_library.dart';

void main() {
  test('용량 막대의 사진 크기는 기기에 한 번에 묻고, 다시 묻지 않는다 (리뷰 2026-10-31 S-4)', () async {
    var calls = 0;
    final lib = PhotoLibrary(
      bulkSizes: () async {
        calls++;
        return {'a': 10, 'b': 20, 'v': 300};
      },
    );
    expect(await lib.fileSizes(['a', 'b']), {'a': 10, 'b': 20});
    expect(await lib.fileSizes(['b', 'v']), {'b': 20, 'v': 300});
    // 거기 없는 사진(그 뒤 찍은 것)은 하나씩: 찾을 수 없으면 0
    expect(await lib.fileSizes(['new']), {'new': 0});
    expect(calls, 1);
  });

  test('기기가 한 번에 못 주면 지금처럼 하나씩 (S-4)', () async {
    var calls = 0;
    final lib = PhotoLibrary(
      bulkSizes: () async {
        calls++;
        return null;
      },
    );
    expect(await lib.fileSizes(['a']), {'a': 0});
    expect(await lib.fileSizes(['b']), {'b': 0});
    expect(calls, 1);
  });
}
