import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mehh/l10n/l10n.dart';
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
  final ko = lookupL10n(const Locale('ko'));
  final en = lookupL10n(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting('ko');
    await initializeDateFormatting('en');
  });

  test('묶음 제목 (한국어·영어)', () {
    final g = group([DateTime(2026, 10, 3, 13)]);
    expect(groupTitle(g, ko, place: '롯데월드', now: now), '10월 3일 · 롯데월드');
    expect(groupTitle(g, ko, now: now), '10월 3일');
    expect(groupTitle(g, en, now: now), 'Oct 3');
    expect(
      groupTitle(group([DateTime(2025, 1, 2)]), ko, now: now),
      '2025년 1월 2일',
    );
    expect(
      groupTitle(group([DateTime(2025, 1, 2)]), en, now: now),
      'Jan 2, 2025',
    );
    final shots = group([DateTime(2026, 9, 5)], kind: DayGroupKind.screenshots);
    expect(
      groupTitle(group([DateTime(2025, 1, 2)]), ko, now: now, withYear: false),
      '1월 2일',
    ); // 홈 목록: 연도 구분선이 있어서 연도를 뺀다
    expect(groupTitle(shots, ko, now: now), '캡처');
    expect(groupTitle(shots, en, now: now), 'Screenshots');
  });

  test('시간 범위 (한국어·영어)', () {
    final g = group([
      DateTime(2026, 10, 3, 13, 12),
      DateTime(2026, 10, 3, 20, 40),
    ]);
    expect(groupTimeRange(g, ko, now: now), '오후 1:12 – 오후 8:40');
    expect(
      groupTimeRange(g, en, now: now).replaceAll(' ', ' '),
      '1:12 PM – 8:40 PM',
    );
    expect(
      groupTimeRange(
        group([DateTime(2026, 10, 3, 23), DateTime(2026, 10, 4, 0, 30)]),
        ko,
        now: now,
      ),
      '10월 3일 – 10월 4일',
    );
  });

  test('영어는 단수·복수가 맞다', () {
    expect(en.photos(1), '1 photo');
    expect(en.photos(3), '3 photos');
    expect(ko.photos(3), '3장');
    expect(en.trashCount(2), 'Move 2 to trash');
    expect(ko.trashCount(1234), '1,234장 휴지통으로');
  });
}
