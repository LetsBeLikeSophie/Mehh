import '../config/cleanup_config.dart';
import '../models/features.dart';
import '../models/photo_meta.dart';

/// 완전 중복 한 묶음: [keep] 하나만 남기고 [remove]는 휴지통으로.
class DuplicateSet {
  const DuplicateSet(this.keep, this.remove);
  final PhotoMeta keep;
  final List<PhotoMeta> remove;
}

/// 해시는 같아 보이지만 연속 촬영일 수도 있어서 파일 크기로 확인해야 하는 사진들.
Set<String> idsNeedingSize(
  List<PhotoMeta> photos,
  Map<String, PhotoFeatures> features, {
  CleanupConfig config = const CleanupConfig(),
}) {
  final out = <String>{};
  _forEachCandidatePair(photos, features, config, (a, b) {
    if (_sameShotRisk(a, b, features, config)) {
      out
        ..add(a.id)
        ..add(b.id);
    }
  });
  return out;
}

/// SPEC 6-2. [sizes]는 [idsNeedingSize]의 사진 크기 (없으면 그 쌍은 중복 아님).
List<DuplicateSet> findDuplicates(
  List<PhotoMeta> photos,
  Map<String, PhotoFeatures> features, {
  Map<String, int> sizes = const {},
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
  _forEachCandidatePair(photos, features, config, (a, b) {
    if (_sameShotRisk(a, b, features, config)) {
      final sa = sizes[a.id], sb = sizes[b.id];
      if (sa == null || sb == null || sa == 0 || sa != sb) return;
    }
    parent.putIfAbsent(a.id, () => a.id);
    parent.putIfAbsent(b.id, () => b.id);
    final ra = find(a.id), rb = find(b.id);
    if (ra != rb) parent[rb] = ra;
  });

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

void _forEachCandidatePair(
  List<PhotoMeta> photos,
  Map<String, PhotoFeatures> features,
  CleanupConfig config,
  void Function(PhotoMeta a, PhotoMeta b) visit,
) {
  // 가로세로 비율로 먼저 나눠 비교 횟수를 줄인다
  final buckets = <int, List<(PhotoMeta, PhotoFeatures)>>{};
  for (final p in photos) {
    final f = features[p.id];
    if (f == null || p.aspect == 0) continue;
    final key = (p.aspect * 100).round();
    buckets.putIfAbsent(key, () => []).add((p, f));
  }
  for (final list in buckets.values) {
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        if (list[i].$2.hammingTo(list[j].$2) <= config.duplicateMaxHamming) {
          visit(list[i].$1, list[j].$1);
        }
      }
    }
  }
}
