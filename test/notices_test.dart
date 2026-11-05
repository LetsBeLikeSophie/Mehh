import 'package:flutter_test/flutter_test.dart';

import 'package:mehh/data/notices.dart';

/// 플러그인은 첫 알림 뒤 "UTC로 같은 날짜·시각"으로 되풀이한다.
/// 그래서 UTC로 1일이고, 이 폰 시각(여름시간 ±1시간 포함)으로도 1일이면 매달 맞다 (B-33)
void main() {
  for (final hours in [14, 13, 12.75, 12, 9, 0, -5, -12]) {
    final offset = Duration(minutes: (hours * 60).round());
    test('시차 ${hours >= 0 ? '+' : ''}$hours: 다음 세 번 모두 그 나라 1일 (Q1-A)', () {
      for (final now in [
        DateTime(2026, 11, 5),
        DateTime(2026, 12, 31),
        DateTime(2027, 1, 20),
      ]) {
        final at = monthlyNoticeAt(now, offset: offset);
        expect(at.isUtc, isTrue);
        expect(at.day, 1);
        for (final dst in [-1, 0, 1]) {
          final local = at.add(offset + Duration(hours: dst));
          expect(local.day, 1, reason: '$now · 여름시간 $dst');
        }
      }
    });
  }

  test('보통 나라(+9·−5)는 그대로 낮 12시', () {
    for (final h in [9, -5]) {
      final at = monthlyNoticeAt(
        DateTime(2026, 11, 5),
        offset: Duration(hours: h),
      );
      expect(at.add(Duration(hours: h)).hour, 12);
      expect(at.month, 12);
    }
  });
}
