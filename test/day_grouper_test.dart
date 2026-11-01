import 'package:flutter_test/flutter_test.dart';
import 'package:mehh/config/grouping_config.dart';
import 'package:mehh/logic/day_grouper.dart';
import 'package:mehh/logic/screen_detect.dart';
import 'package:mehh/models/day_group.dart';
import 'package:mehh/models/photo_meta.dart';

var _n = 0;

void savedGroupTests() {
  test('카메라 밖 사진은 그날의 묶음·낱장에 안 들어가고 저장한 사진 하나로 (2026-11-01 Sophie)', () {
    final t = DateTime(2026, 9, 1, 10);
    PhotoMeta p(String id, {bool other = false, bool shot = false}) =>
        PhotoMeta(
          id: id,
          takenAt: t,
          width: 100,
          height: 100,
          fromOtherApp: other,
          isScreenshot: shot,
        );
    final groups = groupPhotos([
      p('c'),
      p('pin', other: true),
      p('kakao', other: true),
      p('s', shot: true, other: true),
    ], config: one);
    List<String> ids(DayGroupKind k) => [
      for (final g in groups)
        if (g.kind == k)
          for (final x in g.photos) x.id,
    ];
    expect(ids(DayGroupKind.day), ['c']);
    expect(ids(DayGroupKind.saved), unorderedEquals(['pin', 'kakao']));
    expect(ids(DayGroupKind.screenshots), ['s']); // 캡처가 먼저
  });

  test('카메라 폴더 판별 (2026-11-01 Sophie)', () {
    for (final path in [
      'DCIM/Camera/',
      'dcim/camera',
      'DCIM/100ANDRO/',
      'DCIM/',
      'Camera/',
      'Pictures/Camera/',
      '',
      null,
    ]) {
      expect(isCameraPath(path), isTrue, reason: '$path');
    }
    for (final path in [
      'Pictures/Pinterest/',
      'Download/',
      'Pictures/KakaoTalk/',
      'Movies/CapCut/',
      'DCIM/B612/',
      'DCIM/CapCut/',
    ]) {
      expect(isCameraPath(path), isFalse, reason: path);
    }
  });
}

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

// 기존 규칙 테스트는 한 장짜리 묶음도 그대로 두고 본다
const one = GroupingConfig(minDayPhotos: 1);

void main() {
  savedGroupTests();
  test('3시간 이상 벌어지면 새 묶음', () {
    final groups = groupPhotos([
      photo(DateTime(2026, 10, 3, 10)),
      photo(DateTime(2026, 10, 3, 12, 59)),
      photo(DateTime(2026, 10, 3, 15, 59)),
    ], config: one);
    expect(groups.map((g) => g.count), [1, 2]);
  });

  test('위치가 2km 이상 떨어지면 새 묶음', () {
    final groups = groupPhotos([
      photo(DateTime(2026, 10, 3, 10), lat: 37.511, lng: 127.098),
      photo(DateTime(2026, 10, 3, 10, 30), lat: 37.512, lng: 127.099),
      // 약 5km 떨어진 곳
      photo(DateTime(2026, 10, 3, 11), lat: 37.544, lng: 127.056),
    ], config: one);
    expect(groups.length, 2);
  });

  test('한쪽만 위치가 있으면 거리로 나누지 않는다', () {
    final groups = groupPhotos([
      photo(DateTime(2026, 10, 3, 10), lat: 37.511, lng: 127.098),
      photo(DateTime(2026, 10, 3, 10, 30)),
      photo(DateTime(2026, 10, 3, 11), lat: 37.544, lng: 127.056),
    ], config: one);
    expect(groups.length, 1);
  });

  test('자정을 넘기고 1시간 이상이면 새 묶음, 미만이면 유지', () {
    final split = groupPhotos([
      photo(DateTime(2026, 10, 3, 23, 30)),
      photo(DateTime(2026, 10, 4, 0, 40)),
    ], config: one);
    expect(split.length, 2);

    final keep = groupPhotos([
      photo(DateTime(2026, 10, 3, 23, 30)),
      photo(DateTime(2026, 10, 4, 0, 20)),
    ], config: one);
    expect(keep.length, 1);
  });

  test('캡처는 전부 하나로, 한 장짜리 날은 "낱장 사진"으로 모은다', () {
    final groups = groupPhotos([
      photo(DateTime(2026, 9, 1, 10)),
      photo(DateTime(2026, 9, 1, 10, 5), shot: true),
      photo(DateTime(2026, 9, 1, 10, 10)),
      photo(DateTime(2026, 9, 20), shot: true),
      photo(DateTime(2026, 9, 25, 9)), // 한 장짜리 날
      photo(DateTime(2026, 10, 2), shot: true),
      photo(DateTime(2026, 10, 5, 9)), // 한 장짜리 날
    ]);
    expect(groups.map((g) => g.kind), [
      DayGroupKind.day,
      DayGroupKind.singles,
      DayGroupKind.screenshots,
    ]);
    expect(groups.map((g) => g.count), [2, 2, 3]);
  });

  test('최신 묶음이 먼저, 묶음 안은 시간순', () {
    final groups = groupPhotos([
      photo(DateTime(2026, 10, 3, 12)),
      photo(DateTime(2026, 9, 1)),
      photo(DateTime(2026, 10, 3, 11)),
    ], config: one);
    expect(groups.first.start, DateTime(2026, 10, 3, 11));
    expect(groups.first.end, DateTime(2026, 10, 3, 12));
  });

  test('묶음 중심 좌표는 위치 있는 사진의 평균', () {
    final g = groupPhotos([
      photo(DateTime(2026, 10, 3, 10), lat: 37.0, lng: 127.0),
      photo(DateTime(2026, 10, 3, 10, 1)),
      photo(DateTime(2026, 10, 3, 10, 2), lat: 37.002, lng: 127.002),
    ], config: one).single;
    expect(g.centerLat, closeTo(37.001, 1e-9));
    expect(g.centerLng, closeTo(127.001, 1e-9));
  });
}
