import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/data/billing.dart';
import 'package:mehh/logic/pick_stats.dart';
import 'package:mehh/logic/recommend.dart';
import 'package:mehh/models/pick.dart';

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

  test('취향 학습: 20장 넘게 봤는데 절반도 안 받아들인 이유는 더 추천하지 않는다', () {
    final at = DateTime(2026, 10, 22);
    PickRecord r(String tag, bool sent) =>
        PickRecord(at: at, kind: 'day', tag: tag, suggested: true, sent: sent);
    final records = [
      for (var i = 0; i < 20; i++) r('blurry', i < 6), // 30%
      for (var i = 0; i < 20; i++) r('burst', i < 15), // 75%
      for (var i = 0; i < 5; i++) r('junk', false), // 아직 적음
    ];
    expect(mutedReasons(PickStats.of(records)), {TrashReason.blurry});
  });

  test('눈 감음 추천도 정확도 기록·취향 학습에 들어간다 (자주 남기면 끈다)', () {
    final records = [
      for (var i = 0; i < 20; i++)
        PickRecord(
          at: DateTime(2026, 10, 20),
          kind: 'day',
          tag: 'eyesClosed',
          suggested: true,
          sent: i < 5,
        ),
    ];
    expect(mutedReasons(PickStats.of(records)), {TrashReason.eyesClosed});
  });

  test('취향 학습은 최근 30일 기록만 본다 (꺼진 이유도 30일 뒤엔 다시 추천)', () {
    PickRecord r(DateTime at, bool sent) => PickRecord(
      at: at,
      kind: 'day',
      tag: 'blurry',
      suggested: true,
      sent: sent,
    );
    final old = DateTime(2026, 9, 1);
    final records = [for (var i = 0; i < 20; i++) r(old, false)];
    expect(
      mutedReasons(
        PickStats.of(recentPicks(records, now: DateTime(2026, 9, 10))),
      ),
      {TrashReason.blurry},
    );
    expect(
      mutedReasons(
        PickStats.of(recentPicks(records, now: DateTime(2026, 10, 15))),
      ),
      isEmpty,
    );
  });
}
