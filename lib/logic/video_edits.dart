import '../models/photo_meta.dart';

/// 편집한 동영상과 그 원본 묶음 (2026-11-07 Sophie: 같이 보여 주고 하나만 남기게).
/// [sets]: 묶음마다 원본 먼저, 그다음 편집본(만든 순). 최근 묶음이 앞.
/// [edited]: 편집본 id
typedef EditSets = ({List<List<PhotoMeta>> sets, Set<String> edited});

/// 원본 정보가 남는 경우만 짝으로 본다 (폰 시험 2026-11-07):
/// - 캡컷: 파일 안에 원본 동영상 id를 적어 둔다 → [PhotoMeta.editedFrom]
/// - 삼성 편집기: 카메라 폴더 밖에 "원본이름_1"로 저장하고 찍은 시각을 원본 그대로 둔다
/// 인샷처럼 원본 정보를 다 지우는 앱은 짐작하지 않는다.
EditSets findEditSets(List<PhotoMeta> videos) {
  final byId = {for (final v in videos) v.id: v};
  final byStem = <String, List<PhotoMeta>>{};
  for (final v in videos) {
    if (v.fileName case final n?) (byStem[_stem(n)] ??= []).add(v);
  }

  final parent = <String, String>{};
  String root(String id) {
    var r = id;
    for (var p = parent[r]; p != null; p = parent[r]) {
      r = p;
    }
    return r;
  }

  final edited = <String>{};
  final linked = <String>{};
  void link(PhotoMeta edit, PhotoMeta source) {
    edited.add(edit.id);
    linked
      ..add(edit.id)
      ..add(source.id);
    final a = root(edit.id), b = root(source.id);
    if (a != b) parent[a] = b;
  }

  for (final v in videos) {
    // 캡컷이 적은 번호는 그 폰의 id라, 다른 폰에서 옮겨 온 영상이면 엉뚱한 영상을 가리킬 수 있다.
    // 원본답게 찍은 시각이 있고, 편집본보다 먼저 찍혔고, 자신은 편집본이 아닐 때만 (리뷰 11-07 S-1)
    final src = byId[v.editedFrom];
    final at0 = src?.capturedAt;
    if (src != null &&
        src.id != v.id &&
        at0 != null &&
        src.editedFrom == null &&
        !at0.isAfter(v.takenAt)) {
      link(v, src);
      continue;
    }
    final name = v.fileName, at = v.capturedAt;
    if (name == null || at == null || !v.fromOtherApp) continue;
    final m = _suffix.firstMatch(_stem(name));
    if (m == null) continue;
    for (final s in byStem[m.group(1)!] ?? const <PhotoMeta>[]) {
      final t = s.capturedAt;
      if (s.id != v.id && t != null && t.difference(at).abs() <= sameShot) {
        link(v, s);
        break;
      }
    }
  }

  final groups = <String, List<PhotoMeta>>{};
  for (final v in videos) {
    if (linked.contains(v.id)) (groups[root(v.id)] ??= []).add(v);
  }
  final sets = [
    for (final s in groups.values)
      [
        ...s.where((v) => !edited.contains(v.id)),
        ...s.where((v) => edited.contains(v.id)).toList()
          ..sort((a, b) => a.takenAt.compareTo(b.takenAt)),
      ],
  ];
  DateTime newest(List<PhotoMeta> s) =>
      s.map((v) => v.takenAt).reduce((a, b) => a.isAfter(b) ? a : b);
  sets.sort((a, b) => newest(b).compareTo(newest(a)));
  return (sets: sets, edited: edited);
}

/// 캡컷이 내보낸 영상 이름 ("lv_0_20261107041537.mp4"). 원본 id를 찾으려고 파일을 여는 것은 이것만
bool isCapCutName(String? name) =>
    name?.toLowerCase().startsWith('lv_') ?? false;

/// 같은 장면으로 보는 찍은 시각 차이 (삼성 편집본이 원본과 42초 어긋난 예가 있었다)
const sameShot = Duration(minutes: 2);

final _suffix = RegExp(r'^(.+)_\d{1,2}$');

String _stem(String name) {
  final dot = name.lastIndexOf('.');
  return (dot > 0 ? name.substring(0, dot) : name).toLowerCase();
}

/// 동영상 묶음 안의 세 칸 (2026-11-08 Sophie: 찍은·받은·편집 세 줄을 하나로 합치고 안에서 나눔).
/// 영상 하나는 한 칸에만: 짝이 있으면 [pairs], 아니면 카메라로 찍은 [filmed], 나머지는 [saved].
/// [filmed]·[saved]는 용량 큰 순
typedef VideoSections = ({
  List<List<PhotoMeta>> pairs,
  Set<String> edited,
  List<PhotoMeta> filmed,
  List<PhotoMeta> saved,
});

VideoSections videoSections(List<PhotoMeta> videos) {
  final e = findEditSets(videos);
  final inPairs = {
    for (final s in e.sets)
      for (final v in s) v.id,
  };
  List<PhotoMeta> rest({required bool otherApp}) => [
    for (final v in videos)
      if (!inPairs.contains(v.id) && v.fromOtherApp == otherApp) v,
  ]..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
  return (
    pairs: e.sets,
    edited: e.edited,
    filmed: rest(otherApp: false),
    saved: rest(otherApp: true),
  );
}

/// 화면에 보이는 순서 그대로 (짝 → 찍은 → 받은)
List<PhotoMeta> videoOrder(List<PhotoMeta> videos) {
  final s = videoSections(videos);
  return [for (final p in s.pairs) ...p, ...s.filmed, ...s.saved];
}
