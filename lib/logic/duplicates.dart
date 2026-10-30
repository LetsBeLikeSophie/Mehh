import '../config/cleanup_config.dart';
import '../models/features.dart';
import '../models/photo_meta.dart';

/// 완전 중복 한 묶음: [keep] 하나만 남기고 [remove]는 휴지통으로.
class DuplicateSet {
  const DuplicateSet(this.keep, this.remove);
  final PhotoMeta keep;
  final List<PhotoMeta> remove;
}

/// 해시가 거의 같은 쌍. [idsNeedingSize]와 [findDuplicates]에 같이 넘기면 한 번만 찾는다
typedef DuplicatePairs = List<(PhotoMeta, PhotoMeta)>;

/// 해시는 같아 보이지만 연속 촬영일 수도 있어서 파일 크기로 확인해야 하는 사진들.
Set<String> idsNeedingSize(
  List<PhotoMeta> photos,
  Map<String, PhotoFeatures> features, {
  DuplicatePairs? pairs,
  CleanupConfig config = const CleanupConfig(),
}) {
  final out = <String>{};
  for (final (a, b)
      in pairs ?? duplicatePairs(photos, features, config: config)) {
    if (_sameShotRisk(a, b, features, config)) {
      out
        ..add(a.id)
        ..add(b.id);
    }
  }
  return out;
}

/// SPEC 6-2. [sizes]는 [idsNeedingSize]의 사진 크기 (없으면 그 쌍은 중복 아님).
List<DuplicateSet> findDuplicates(
  List<PhotoMeta> photos,
  Map<String, PhotoFeatures> features, {
  Map<String, int> sizes = const {},
  DuplicatePairs? pairs,
  CleanupConfig config = const CleanupConfig(),
}) {
  final parent = <String, String>{};
  String find(String x) {
    while (parent[x] != null && parent[x] != x) {
      x = parent[x]!;
    }
    return x;
  }

  final byId = {for (final p in photos) p.id: p};
  for (final (a, b)
      in pairs ?? duplicatePairs(photos, features, config: config)) {
    if (_sameShotRisk(a, b, features, config)) {
      final sa = sizes[a.id], sb = sizes[b.id];
      if (sa == null || sb == null || sa == 0 || sa != sb) continue;
    }
    parent.putIfAbsent(a.id, () => a.id);
    parent.putIfAbsent(b.id, () => b.id);
    final ra = find(a.id), rb = find(b.id);
    if (ra != rb) parent[rb] = ra;
  }

  final clusters = <String, List<PhotoMeta>>{};
  for (final id in parent.keys) {
    clusters.putIfAbsent(find(id), () => []).add(byId[id]!);
  }
  final sets = <DuplicateSet>[];
  for (final c in clusters.values) {
    // 해상도가 가장 크고, 같으면 가장 먼저 찍힌 것을 남긴다
    c.sort((a, b) {
      final r = (b.width * b.height).compareTo(a.width * a.height);
      return r != 0 ? r : a.takenAt.compareTo(b.takenAt);
    });
    sets.add(DuplicateSet(c.first, c.sublist(1)));
  }
  sets.sort((a, b) => b.keep.takenAt.compareTo(a.keep.takenAt));
  return sets;
}

/// 해시만으로는 못 믿는 쌍:
/// 같은 크기로 짧은 시간 안에 찍힌 사진(연속 촬영),
/// 스크린샷·글자 많은 사진(같은 앱 화면은 글자만 달라도 해시가 거의 같다.
/// 예: 택시 이용 내역 여러 장)
bool _sameShotRisk(
  PhotoMeta a,
  PhotoMeta b,
  Map<String, PhotoFeatures> features,
  CleanupConfig c,
) =>
    a.isScreenshot ||
    b.isScreenshot ||
    (features[a.id]?.textScore ?? 0) >= c.textScreenshot ||
    (features[b.id]?.textScore ?? 0) >= c.textScreenshot ||
    (a.width == b.width &&
        a.height == b.height &&
        a.takenAt.difference(b.takenAt).abs() <= c.sameShotWindow);

/// 가로세로 비율이 같고 해시가 [CleanupConfig.duplicateMaxHamming] 비트 안으로 다른 쌍.
/// 64비트 해시를 (max+1) 조각으로 나누면 그런 쌍은 적어도 한 조각이 똑같다(비둘기집).
/// 같은 조각을 가진 것끼리만 비교해, 같은 비율 사진 전체를 서로 비교하지 않는다
/// (리뷰 2026-10-30 S-4: 1만 장이면 [휴지통으로]마다 몇 초씩 걸렸다)
DuplicatePairs duplicatePairs(
  List<PhotoMeta> photos,
  Map<String, PhotoFeatures> features, {
  CleanupConfig config = const CleanupConfig(),
}) {
  // 가로세로 비율로 먼저 나눈다
  final buckets = <int, List<(PhotoMeta, PhotoFeatures)>>{};
  for (final p in photos) {
    final f = features[p.id];
    if (f == null || p.aspect == 0) continue;
    final key = (p.aspect * 100).round();
    buckets.putIfAbsent(key, () => []).add((p, f));
  }
  final max = config.duplicateMaxHamming;
  // 조각이 32비트를 넘지 않게 적어도 둘로 (웹에서도 비트 연산이 맞도록)
  final pieces = max + 1 < 2 ? 2 : max + 1;
  final out = <(PhotoMeta, PhotoMeta)>[];
  for (final list in buckets.values) {
    final n = list.length;
    final found = <int>{};
    for (var k = 0; k < pieces; k++) {
      final same = <int, List<int>>{};
      for (var i = 0; i < n; i++) {
        same.putIfAbsent(_piece(list[i].$2, k, pieces), () => []).add(i);
      }
      for (final g in same.values) {
        for (var x = 0; x < g.length; x++) {
          for (var y = x + 1; y < g.length; y++) {
            final i = g[x], j = g[y];
            if (list[i].$2.hammingTo(list[j].$2) <= max) found.add(i * n + j);
          }
        }
      }
    }
    // 예전처럼 사진 순서대로 (묶음 안 순서가 흔들리지 않게)
    for (final key in found.toList()..sort()) {
      out.add((list[key ~/ n].$1, list[key % n].$1));
    }
  }
  return out;
}

/// 64비트 해시의 [k]번째 조각 (비트 0~31 = hashLo, 32~63 = hashHi)
int _piece(PhotoFeatures f, int k, int pieces) {
  final start = k * 64 ~/ pieces, end = (k + 1) * 64 ~/ pieces;
  var v = 0;
  for (var b = start; b < end; b++) {
    final word = b < 32 ? f.hashLo : f.hashHi;
    v = (v << 1) | ((word >> (b & 31)) & 1);
  }
  return v;
}

/// 중복 묶음에서 남길 사진: 정리 줄·휴지통에 가지 않은 사진 중 가장 앞(가장 큰) 것.
/// 사용자가 원본을 정리하면 다음 사진이 남길 사진이 된다. 전부 갔으면 null.
String? keeperOf(DuplicateSet s, bool Function(String id) gone) {
  for (final p in [s.keep, ...s.remove]) {
    if (!gone(p.id)) return p.id;
  }
  return null;
}
