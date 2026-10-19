import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/logic/format.dart';
import 'package:mehh/models/day_group.dart';
import 'package:mehh/models/photo_meta.dart';

DayGroup group(List<DateTime> times, {DayGroupKind kind = DayGroupKind.day}) =>
    DayGroup(
      id: 'g',
      kind: kind,
      photos: [
        for (final t in times)
          PhotoMeta(id: '$t', takenAt: t, width: 1, height: 1),
      ],
    );

void main() {
  final now = DateTime(2026, 10, 19);

  test('묶음 제목', () {
    final g = group([DateTime(2026, 10, 3, 13)]);
    expect(groupTitle(g, place: '롯데월드', now: now), '10월 3일 · 롯데월드');
    expect(groupTitle(g, now: now), '10월 3일');
    expect(groupTitle(group([DateTime(2025, 1, 2)]), now: now), '2025년 1월 2일');
    expect(
      groupTitle(
        group([DateTime(2026, 9, 5)], kind: DayGroupKind.screenshots),
        now: now,
      ),
      '9월 · 캡처 모음',
    );
  });

  test('시간 범위', () {
    expect(
      groupTimeRange(
        group([DateTime(2026, 10, 3, 13, 12), DateTime(2026, 10, 3, 20, 40)]),
        now: now,
      ),
      '오후 1:12 – 8:40',
    );
    expect(
      groupTimeRange(
        group([DateTime(2026, 10, 3, 9, 5), DateTime(2026, 10, 3, 12, 0)]),
        now: now,
      ),
      '오전 9:05 – 오후 12:00',
    );
    expect(
      groupTimeRange(
        group([DateTime(2026, 10, 3, 23), DateTime(2026, 10, 4, 0, 30)]),
        now: now,
      ),
      '10월 3일 – 10월 4일',
    );
  });
}
