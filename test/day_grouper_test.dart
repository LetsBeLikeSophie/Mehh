import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/logic/day_grouper.dart';
import 'package:mehh/models/day_group.dart';
import 'package:mehh/models/photo_meta.dart';

var _n = 0;
PhotoMeta photo(DateTime t, {double? lat, double? lng, bool shot = false}) =>
    PhotoMeta(
      id: '${_n++}',
      takenAt: t,
      width: 100,
      height: 100,
      lat: lat,
      lng: lng,
      isScreenshot: shot,
    );

void main() {
  test('3시간 이상 벌어지면 새 묶음', () {
    final groups = groupPhotos([
      photo(DateTime(2026, 10, 3, 10)),
      photo(DateTime(2026, 10, 3, 12, 59)),
      photo(DateTime(2026, 10, 3, 15, 59)),
    ]);
    expect(groups.map((g) => g.count), [1, 2]);
  });

  test('위치가 2km 이상 떨어지면 새 묶음', () {
    final groups = groupPhotos([
      photo(DateTime(2026, 10, 3, 10), lat: 37.511, lng: 127.098),
      photo(DateTime(2026, 10, 3, 10, 30), lat: 37.512, lng: 127.099),
      // 약 5km 떨어진 곳
      photo(DateTime(2026, 10, 3, 11), lat: 37.544, lng: 127.056),
    ]);
    expect(groups.length, 2);
  });

  test('한쪽만 위치가 있으면 거리로 나누지 않는다', () {
    final groups = groupPhotos([
      photo(DateTime(2026, 10, 3, 10), lat: 37.511, lng: 127.098),
      photo(DateTime(2026, 10, 3, 10, 30)),
      photo(DateTime(2026, 10, 3, 11), lat: 37.544, lng: 127.056),
    ]);
    expect(groups.length, 1);
  });

  test('자정을 넘기고 1시간 이상이면 새 묶음, 미만이면 유지', () {
    final split = groupPhotos([
      photo(DateTime(2026, 10, 3, 23, 30)),
      photo(DateTime(2026, 10, 4, 0, 40)),
    ]);
    expect(split.length, 2);

    final keep = groupPhotos([
      photo(DateTime(2026, 10, 3, 23, 30)),
      photo(DateTime(2026, 10, 4, 0, 20)),
    ]);
    expect(keep.length, 1);
  });

  test('스크린샷은 월별 캡처 모음으로 빠진다', () {
    final groups = groupPhotos([
      photo(DateTime(2026, 9, 1, 10)),
      photo(DateTime(2026, 9, 1, 10, 5), shot: true),
      photo(DateTime(2026, 9, 1, 10, 10)),
      photo(DateTime(2026, 9, 20), shot: true),
      photo(DateTime(2026, 10, 2), shot: true),
    ]);
    final shots = groups.where((g) => g.kind == DayGroupKind.screenshots);
    expect(shots.map((g) => g.count), [1, 2]);
    final days = groups.where((g) => g.kind == DayGroupKind.day);
    expect(days.single.count, 2);
  });

  test('최신 묶음이 먼저, 묶음 안은 시간순', () {
    final groups = groupPhotos([
      photo(DateTime(2026, 10, 3, 12)),
      photo(DateTime(2026, 9, 1)),
      photo(DateTime(2026, 10, 3, 11)),
    ]);
    expect(groups.first.start, DateTime(2026, 10, 3, 11));
    expect(groups.first.end, DateTime(2026, 10, 3, 12));
  });

  test('묶음 중심 좌표는 위치 있는 사진의 평균', () {
    final g = groupPhotos([
      photo(DateTime(2026, 10, 3, 10), lat: 37.0, lng: 127.0),
      photo(DateTime(2026, 10, 3, 10, 1)),
      photo(DateTime(2026, 10, 3, 10, 2), lat: 37.002, lng: 127.002),
    ]).single;
    expect(g.centerLat, closeTo(37.001, 1e-9));
    expect(g.centerLng, closeTo(127.001, 1e-9));
  });
}
