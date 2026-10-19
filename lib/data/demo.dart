import 'package:photo_manager/photo_manager.dart';

import '../models/photo_meta.dart';
import 'photo_library.dart';
import 'place_namer.dart';

// 웹 미리보기용 샘플 데이터. 브라우저는 사진첩에 접근할 수 없어서
// 화면과 동작만 확인할 수 있게 가짜 사진을 만든다.

class _Place {
  const _Place(this.name, this.lat, this.lng);
  final String name;
  final double lat;
  final double lng;
}

class _Day {
  const _Day(this.start, this.end, this.count, this.place);
  final DateTime start;
  final DateTime end;
  final int count;
  final _Place place;
}

const _mangwon = _Place('망원동', 37.556, 126.901);
const _lotte = _Place('롯데월드', 37.511, 127.098);
const _seongsu = _Place('성수동 카페', 37.544, 127.056);
const _hangang = _Place('한강공원', 37.528, 126.934);
const _jeju = _Place('협재해변', 33.394, 126.239);
const _yeonnam = _Place('연남동', 37.562, 126.925);
const _haeundae = _Place('해운대', 35.159, 129.160);

final _days = [
  _Day(
    DateTime(2026, 10, 17, 12, 20),
    DateTime(2026, 10, 17, 15, 5),
    32,
    _mangwon,
  ),
  _Day(
    DateTime(2026, 10, 3, 13, 12),
    DateTime(2026, 10, 3, 20, 40),
    214,
    _lotte,
  ),
  _Day(
    DateTime(2026, 9, 21, 14, 2),
    DateTime(2026, 9, 21, 16, 30),
    46,
    _seongsu,
  ),
  _Day(
    DateTime(2026, 9, 14, 17, 10),
    DateTime(2026, 9, 14, 21, 45),
    88,
    _hangang,
  ),
  _Day(DateTime(2026, 9, 6, 10, 30), DateTime(2026, 9, 6, 18, 20), 120, _jeju),
  _Day(
    DateTime(2026, 8, 30, 19, 0),
    DateTime(2026, 8, 30, 21, 10),
    18,
    _yeonnam,
  ),
  _Day(
    DateTime(2026, 8, 15, 9, 40),
    DateTime(2026, 8, 15, 19, 55),
    156,
    _haeundae,
  ),
];

// 월별 캡처 장수
final _shots = {
  DateTime(2026, 10): 12,
  DateTime(2026, 9): 63,
  DateTime(2026, 8): 30,
};

List<PhotoMeta> demoPhotos() {
  final out = <PhotoMeta>[];
  var n = 0;
  for (final d in _days) {
    final span = d.end.difference(d.start).inSeconds;
    for (var i = 0; i < d.count; i++) {
      final t = d.count == 1 ? 0 : span * i ~/ (d.count - 1);
      out.add(
        PhotoMeta(
          id: 'demo-${n++}',
          takenAt: d.start.add(Duration(seconds: t)),
          width: 3024,
          height: 4032,
          lat: d.place.lat,
          lng: d.place.lng,
        ),
      );
    }
  }
  for (final e in _shots.entries) {
    for (var i = 0; i < e.value; i++) {
      out.add(
        PhotoMeta(
          id: 'demo-${n++}',
          takenAt: e.key.add(Duration(hours: 10 + i * 9)),
          width: 1080,
          height: 2340,
          isScreenshot: true,
        ),
      );
    }
  }
  return out;
}

class DemoPhotoLibrary extends PhotoLibrary {
  var _state = PermissionState.notDetermined;

  @override
  Future<PermissionState> permissionState() async => _state;

  @override
  Future<PermissionState> requestPermission() async =>
      _state = PermissionState.authorized;

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> presentLimited() async {}

  @override
  Future<List<PhotoMeta>> loadAll() async => demoPhotos();

  @override
  Future<Map<String, (double, double)>> fillLocations(
    List<PhotoMeta> metas, {
    void Function(int done, int total)? onProgress,
  }) async => {};
}

class DemoPlaceNamer extends PlaceNamer {
  static final _names = {
    for (final d in _days)
      PlaceNamer.keyOf(d.place.lat, d.place.lng): d.place.name,
  };

  @override
  Future<String?> nameOf(double lat, double lng) async =>
      _names[PlaceNamer.keyOf(lat, lng)];
}
