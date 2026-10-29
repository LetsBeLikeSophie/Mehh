part of '../providers.dart';

// 사용자 결정 (킵·정리·휴지통)

// ───────────────────────── 사용자 결정

class DecisionsNotifier extends AsyncNotifier<Map<String, Decision>> {
  @override
  Future<Map<String, Decision>> build() =>
      ref.read(storeProvider).loadDecisions();

  /// 결정을 바꾸고, 되돌리기용으로 이전 결정을 돌려준다.
  Future<Map<String, Decision?>> set(
    Iterable<String> ids,
    DecisionState s,
  ) async {
    final now = DateTime.now();
    final cur = state.value ?? {};
    final before = {for (final id in ids) id: cur[id]};
    final list = [
      for (final id in ids) Decision(photoId: id, state: s, at: now),
    ];
    // 저장을 기다리는 사이 다른 결정이 들어올 수 있다(끌어서 여러 장 선택): 지금 상태 위에 더한다
    state = AsyncData({
      ...state.value ?? {},
      for (final d in list) d.photoId: d,
    });
    await ref.read(storeProvider).saveDecisions(list);
    return before;
  }

  /// [set]이 돌려준 이전 결정으로 되돌린다.
  Future<void> restore(Map<String, Decision?> before) async {
    final now = DateTime.now();
    final list = [
      for (final e in before.entries)
        e.value ??
            Decision(photoId: e.key, state: DecisionState.undecided, at: now),
    ];
    await ref.read(storeProvider).saveDecisions(list);
    state = AsyncData({
      ...state.value ?? {},
      for (final d in list) d.photoId: d,
    });
  }
}

final decisionsProvider =
    AsyncNotifierProvider<DecisionsNotifier, Map<String, Decision>>(
      DecisionsNotifier.new,
    );

/// 사진의 결정 상태. 예전에 저장된 보류는 표시 없음(undecided)으로 본다.
DecisionState stateOf(Map<String, Decision> decisions, String id) {
  final s = decisions[id]?.state;
  return s == null || s == DecisionState.hold ? DecisionState.undecided : s;
}
