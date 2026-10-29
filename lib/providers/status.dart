part of '../providers.dart';

// 다 봤어요·Cortex 표시·묶음 상태

/// "다 봤어요" 기준 (2026-10-21): 모든 사진을 정할 필요 없이, 추천을 다 처리하면 끝.
/// 표시 없는 사진은 앱이 다시 추천하지 않으니 그대로 둔다.
/// 잠긴 채로 직접 정리해 보낸 묶음의 사진 (R3, [Store.addSeen])
class SeenNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() => ref.read(storeProvider).loadSeen();

  Future<void> mark(Iterable<String> photoIds) async {
    final ids = photoIds.toList();
    if (ids.isEmpty) return;
    await ref.read(storeProvider).addSeen(ids);
    state = AsyncData({...state.value ?? {}, ...ids});
  }
}

final seenProvider = AsyncNotifierProvider<SeenNotifier, Set<String>>(
  SeenNotifier.new,
);

/// Cortex로 보낸 사진 → Cortex가 받았는지 ([Store.addCortexSent])
class CortexSentNotifier extends AsyncNotifier<Map<String, bool>> {
  @override
  Future<Map<String, bool>> build() => ref.read(storeProvider).loadCortexSent();

  Future<void> add(Iterable<String> photoIds, {bool got = false}) async {
    final ids = photoIds.toList();
    if (ids.isEmpty) return;
    await ref.read(storeProvider).addCortexSent(ids, got: got);
    state = AsyncData({...state.value ?? {}, for (final id in ids) id: got});
  }

  Future<void> remove(Iterable<String> photoIds) async {
    final now = state.value ?? const {};
    final ids = photoIds.where(now.containsKey).toList();
    if (ids.isEmpty) return;
    await ref.read(storeProvider).removeCortexSent(ids);
    state = AsyncData({...now}..removeWhere((k, _) => ids.contains(k)));
  }
}

final cortexSentProvider =
    AsyncNotifierProvider<CortexSentNotifier, Map<String, bool>>(
      CortexSentNotifier.new,
    );

final groupStatusProvider = Provider.autoDispose.family<GroupStatus, DayGroup>((
  ref,
  g,
) {
  final decisions = ref.watch(decisionsProvider).value ?? const {};
  final pile = g.photos.any(
    (p) => stateOf(decisions, p.id) == DecisionState.toTrash,
  );
  final touched = g.photos.any(
    (p) => stateOf(decisions, p.id) != DecisionState.undecided,
  );
  // 캡처 추천(C4)은 무료이고 [추천 보기]로 받는다. 홈의 "정리할 묶음 N개"에 캡처를 셀지는 아직 정하지 않아서
  // 상태는 X가 있을 때만 할 일로 둔다 (줄 아래 글자는 캡처 추천 장수를 보여 준다)
  // 큰 동영상: 앱 추천이 없다. 선택해 두면 할 일, 아니면 그대로
  if (g.kind == DayGroupKind.videos) {
    return pile ? GroupStatus.needsWork : GroupStatus.nothing;
  }
  if (g.kind == DayGroupKind.screenshots) {
    if (pile) return GroupStatus.needsWork;
    // 캡처 추천이 남아 있으면 "다 봤어요"가 아니다 (UX 리뷰 2026-10-23). 큰 숫자에는 세지 않는다
    final picks = planScreenshots(
      g.photos,
      ref.watch(analysisProvider.select((a) => a.features)),
      decisions,
      now: DateTime.now(),
    );
    if (picks.isNotEmpty) return GroupStatus.nothing;
    return touched ? GroupStatus.done : GroupStatus.nothing;
  }
  final plan = ref.watch(groupPlanProvider(g));
  if (pile) return GroupStatus.needsWork;
  if (plan.trash.isNotEmpty) {
    // 잠긴 묶음을 추천 없이 직접 정리해 한 번 보냈으면 "다 봤어요" (보이지 않는 추천으로 남지 않게).
    // 지금 추천이 모두 그때 본 사진일 때만: 그 뒤 새로 찍은 사진에 추천이 생기면 다시 정리할 묶음 (UX-81)
    final seen = ref.watch(seenProvider).value ?? const {};
    final locked =
        g.kind == DayGroupKind.day && !ref.watch(unlockedProvider(g));
    if (locked && plan.trash.keys.every(seen.contains)) {
      return GroupStatus.done;
    }
    return GroupStatus.needsWork;
  }
  if (plan.analyzed < g.count) return GroupStatus.analyzing;
  return touched ? GroupStatus.done : GroupStatus.nothing;
});
