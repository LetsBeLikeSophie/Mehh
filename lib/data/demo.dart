import 'dart:math' as math;

import 'package:photo_manager/photo_manager.dart';

import '../models/features.dart';
import '../models/photo_meta.dart';
import 'photo_library.dart';
import 'place_namer.dart';

// 웹 미리보기용 샘플 데이터. 브라우저는 사진첩에 접근할 수 없어서
// 화면과 동작만 확인할 수 있게 가짜 사진과 분석 결과를 만든다.

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

class _Demo {
  final photos = <PhotoMeta>[];
  final features = <String, PhotoFeatures>{};
  final sizes = <String, int>{};
}

/// 사진은 연속 컷(1~6장, 몇 초 간격)으로 찍힌 것처럼 만든다.
/// 흔들린 사진·까만 사진·카톡으로 다시 저장한 중복도 조금 섞는다.
_Demo _build() {
  final r = math.Random(7);
  final out = _Demo();
  var n = 0;
  int rand32() => r.nextInt(1 << 16) << 16 | r.nextInt(1 << 16);
  int flip(int x, int bits) {
    for (var i = 0; i < bits; i++) {
      x ^= 1 << r.nextInt(32);
    }
    return x;
  }

  void add(PhotoMeta p, PhotoFeatures f, int size) {
    out.photos.add(p);
    out.features[p.id] = f;
    out.sizes[p.id] = size;
  }

  for (final d in _days) {
    final span = d.end.difference(d.start).inSeconds;
    var left = d.count;
    // 연속 컷 시작 시각을 고르게 나눈다
    final starts = <int>[];
    final sizes = <int>[];
    while (left > 0) {
      final s = math.min(left, r.nextDouble() < 0.35 ? 1 : 2 + r.nextInt(5));
      sizes.add(s);
      left -= s;
    }
    for (var b = 0; b < sizes.length; b++) {
      starts.add(sizes.length == 1 ? 0 : span * b ~/ sizes.length);
    }
    for (var b = 0; b < sizes.length; b++) {
      final hi = rand32(), lo = rand32();
      var t = starts[b];
      for (var i = 0; i < sizes[b]; i++) {
        final id = 'demo-${n++}';
        final roll = r.nextDouble();
        add(
          PhotoMeta(
            id: id,
            takenAt: d.start.add(Duration(seconds: t)),
            width: 3024,
            height: 4032,
            lat: d.place.lat,
            lng: d.place.lng,
          ),
          PhotoFeatures(
            id: id,
            hashHi: flip(hi, r.nextInt(3)),
            hashLo: flip(lo, r.nextInt(3)),
            sharpness: roll < 0.08
                ? 4 + r.nextDouble() * 6
                : 80 + r.nextDouble() * 900,
            brightness: roll > 0.985 ? 5 : 70 + r.nextDouble() * 120,
          ),
          2400000 + r.nextInt(2000000),
        );
        t += 3 + r.nextInt(12);
      }
    }
  }

  // 사진이 한 장뿐인 날들 ("한 장 사진"으로 모인다)
  for (final t in [
    DateTime(2026, 10, 14, 8, 20),
    DateTime(2026, 10, 8, 19, 40),
    DateTime(2026, 9, 29, 12, 5),
    DateTime(2026, 9, 17, 23, 50),
    DateTime(2026, 9, 2, 7, 30),
    DateTime(2026, 8, 24, 16, 10),
  ]) {
    final id = 'demo-${n++}';
    add(
      PhotoMeta(id: id, takenAt: t, width: 3024, height: 4032),
      PhotoFeatures(
        id: id,
        hashHi: rand32(),
        hashLo: rand32(),
        sharpness: 40 + r.nextDouble() * 600,
        brightness: 60 + r.nextDouble() * 120,
      ),
      2400000 + r.nextInt(2000000),
    );
  }

  // 카톡으로 받은 뒤 다시 저장한 사진 (10월 10일, 해상도 작음, 해시 거의 같음)
  final originals = out.photos.where((p) => p.lat != null).toList()..shuffle(r);
  for (var i = 0; i < 14; i++) {
    final o = originals[i];
    final of = out.features[o.id]!;
    final id = 'demo-${n++}';
    add(
      PhotoMeta(
        id: id,
        takenAt: DateTime(2026, 10, 10, 22, 5 + i),
        width: 1512,
        height: 2016,
      ),
      PhotoFeatures(
        id: id,
        hashHi: of.hashHi,
        hashLo: flip(of.hashLo, 1),
        sharpness: of.sharpness * 0.9,
        brightness: of.brightness,
      ),
      600000 + r.nextInt(300000),
    );
  }

  for (final e in _shots.entries) {
    for (var i = 0; i < e.value; i++) {
      final id = 'demo-${n++}';
      add(
        PhotoMeta(
          id: id,
          takenAt: e.key.add(Duration(hours: 10 + i * 9)),
          width: 1080,
          height: 2340,
          isScreenshot: true,
        ),
        PhotoFeatures(
          id: id,
          hashHi: rand32(),
          hashLo: rand32(),
          sharpness: 2000,
          brightness: 200,
          textScore: r.nextDouble() < 0.65 ? 0.3 + r.nextDouble() * 0.6 : 0,
        ),
        300000 + r.nextInt(500000),
      );
    }
  }
  return out;
}

class DemoPhotoLibrary extends PhotoLibrary {
  final _demo = _build();
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
  Future<List<PhotoMeta>> loadAll() async => [..._demo.photos];

  @override
  Future<Map<String, (double, double)>> fillLocations(
    List<PhotoMeta> metas, {
    void Function(int done, int total)? onProgress,
  }) async => {};

  /// 실제처럼 조금씩 분석되는 모습을 보여준다.
  @override
  Future<void> analyze(
    List<PhotoMeta> metas, {
    required Future<void> Function(List<PhotoFeatures>) onBatch,
    bool Function()? cancelled,
  }) async {
    const batch = 120;
    for (var i = 0; i < metas.length; i += batch) {
      if (cancelled?.call() ?? false) return;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await onBatch([
        for (final m in metas.skip(i).take(batch)) ?_demo.features[m.id],
      ]);
    }
  }

  @override
  Future<Map<String, int>> fileSizes(Iterable<String> ids) async => {
    for (final id in ids) id: _demo.sizes[id] ?? 0,
  };

  @override
  Future<bool> hasTrash() async => true;

  @override
  Future<List<String>> trash(
    List<String> ids, {
    bool permanentOk = false,
  }) async => ids;

  /// 웹 미리보기에는 실제 파일이 없어 보낸 것으로 친다
  @override
  Future<bool> share(List<String> ids) async => ids.isNotEmpty;

  @override
  Future<void> clearCache() async {}
}

class DemoPlaceNamer extends PlaceNamer {
  static final _names = {
    for (final d in _days)
      PlaceNamer.keyOf(d.place.lat, d.place.lng): d.place.name,
  };

  @override
  Future<void> clearCache() async {}

  @override
  Future<String?> nameOf(double lat, double lng) async =>
      _names[PlaceNamer.keyOf(lat, lng)];
}
