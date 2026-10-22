import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/data/billing.dart';
import 'package:mehh/logic/pick_stats.dart';

void main() {
  test('추천 정확도: 받아들인 비율, 놓친 것, 베스트, 이유별', () {
    final at = DateTime(2026, 10, 21, 12);
    final records = pickRecords(
      at: at,
      kind: 'day',
      shown: ['a', 'b', 'c', 'd', 'e', 'f'],
      // a·b 추천해서 a만 보냄, c는 추천 안 했는데 직접 보냄, d는 베스트를 남김
      sent: {'a', 'c'},
      suggested: {'a', 'b'},
      tags: {'a': 'burst', 'b': 'blurry', 'd': 'best'},
    );
    expect(records.length, 4); // e·f는 셀 게 없어서 안 남긴다

    final s = PickStats.of(records);
    expect(s.sends, 1);
    expect(s.suggested, 2);
    expect(s.accepted, 1);
    expect(s.acceptRate, 0.5);
    expect(s.added, 1);
    expect(s.coverage, 0.5);
    expect(s.best, 1);
    expect(s.bestRate, 1.0);
    expect(s.byTag['burst'], (1, 1));
    expect(s.byTag['blurry'], (0, 1));
  });

  test('기록이 없으면 비율은 없음', () {
    final s = PickStats.of(const []);
    expect(s.sends, 0);
    expect(s.acceptRate, isNull);
  });

  test('결제: 공개키 없는 안드로이드 빌드는 팔지 않고, 확인 실패 구매는 전달 완료로 알리지 않는다', () {
    expect(canSell(android: true, publicKey: ''), isFalse);
    expect(canSell(android: true, publicKey: 'MIIB...'), isTrue);
    expect(
      canSell(android: false, publicKey: ''),
      isTrue,
    ); // App Store는 StoreKit이 확인
    expect(shouldComplete(pending: true, verified: false), isFalse);
    expect(shouldComplete(pending: true, verified: true), isTrue);
    expect(shouldComplete(pending: false, verified: true), isFalse);
  });
}
