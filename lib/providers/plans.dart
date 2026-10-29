part of '../providers.dart';

// 추천 계산 (똑같은 사진, 꺼 둔 이유, 묶음 추천)

// ───────────────────────── 파생 데이터

/// 완전 중복. 분석이 끝나기 전에는 null.
final duplicatesProvider = FutureProvider<List<DuplicateSet>?>((ref) async {
  final photos = ref.watch(libraryProvider.select((s) => s.value?.photos));
  final analysis = ref.watch(analysisProvider);
  if (photos == null || !analysis.done) return null;
  final features = analysis.features;
  final need = await compute(_needSize, (photos, features));
  final sizes = await ref.read(photoLibraryProvider).fileSizes(need);
  return compute(_findDups, (photos, features, sizes));
});

Set<String> _needSize((List<PhotoMeta>, Map<String, PhotoFeatures>) a) =>
    idsNeedingSize(a.$1, a.$2);

List<DuplicateSet> _findDups(
  (List<PhotoMeta>, Map<String, PhotoFeatures>, Map<String, int>) a,
) => findDuplicates(a.$1, a.$2, sizes: a.$3);

/// 아직 고르지 않은 똑같은 사진 수 (홈 카드). 킵·휴지통으로 간 것은 빠진다.
int duplicatesLeft(List<DuplicateSet>? sets, Map<String, Decision> decisions) =>
    sets == null
    ? 0
    : sets.expand((s) => s.remove).where((p) {
        final st = stateOf(decisions, p.id);
        return st == DecisionState.undecided || st == DecisionState.toTrash;
      }).length;

/// 묶음 하나의 추천 정리
/// 자주 되돌린 추천 이유 (취향 학습). 추천 정확도 기록에서 계산하고, 기록이 쌓이면 다시 계산한다.
final mutedReasonsProvider = FutureProvider<Set<TrashReason>>(
  (ref) async => mutedReasons(
    PickStats.of(
      recentPicks(
        await ref.read(storeProvider).loadPicks(),
        now: DateTime.now(),
      ),
    ),
  ),
);

final groupPlanProvider = Provider.autoDispose.family<GroupPlan, DayGroup>((
  ref,
  g,
) {
  final features = ref.watch(analysisProvider.select((s) => s.features));
  final decisions = ref.watch(decisionsProvider).value ?? const {};
  final muted = ref.watch(mutedReasonsProvider).value ?? const {};
  final eyes = ref.watch(eyesClosedProvider).value ?? const {};
  return planGroup(
    g.photos,
    features,
    decisions,
    muted: muted,
    eyesClosed: {
      for (final e in eyes.entries)
        if (e.value) e.key,
    },
  );
});

/// [g]에 붙은 이름의 저장 키. 먼저 묶음 id, 없으면 사진이 가장 많이 겹치는 이름
/// (첫 사진을 지우면 묶음 id가 바뀌어도 이름이 남게, 코인 열림과 같은 방식)
/// 겹침으로 찾기는 그날의 묶음(day-*)끼리만, 그리고 한 이름은 지금 묶음들([all]) 중
/// 가장 많이 겹치는 한 곳에만 (낱장 사진으로 옮겨 간 1장이나 둘로 갈라진 다른 쪽이
/// 이름을 가져가지 않게, UX-47)
String? groupNameKey(
  Map<String, GroupName>? names,
  DayGroup? g, {
  Iterable<DayGroup> all = const [],
}) {
  if (names == null || g == null) return null;
  if (names.containsKey(g.id)) return g.id;
  if (g.kind != DayGroupKind.day) return null;
  int overlap(DayGroup d, GroupName v) =>
      d.photos.where((p) => v.photoIds.contains(p.id)).length;
  String? best;
  var most = 0;
  for (final e in names.entries) {
    if (!e.key.startsWith('day-')) continue;
    final n = overlap(g, e.value);
    if (n == 0) continue;
    // 그 이름의 원래 묶음이 아직 있거나, 더 많이(같게) 겹치는 다른 묶음이 있으면 양보
    final taken = all.any(
      (o) =>
          o.id != g.id &&
          (o.id == e.key ||
              (o.kind == DayGroupKind.day && overlap(o, e.value) >= n)),
    );
    if (taken) continue;
    if (n > most) {
      most = n;
      best = e.key;
    }
  }
  return best;
}
