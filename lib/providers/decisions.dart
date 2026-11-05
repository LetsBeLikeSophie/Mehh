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
    await _save(list);
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
    state = AsyncData({
      ...state.value ?? {},
      for (final d in list) d.photoId: d,
    });
    await _save(list);
  }

  /// 이번 실행에 저장 실패를 이미 알렸는지
  var _told = false;

  /// 저장 공간이 꽉 차 기록을 못 써도 이번 실행의 화면은 그대로 간다. 다음 실행엔 그 결정이 없다.
  /// 그래서 처음 실패한 순간 한 번만 한 줄로 알린다 (리뷰 11-05 S-1, 2026-11-05 Sophie U1-A)
  Future<void> _save(List<Decision> list) async {
    try {
      await ref.read(storeProvider).saveDecisions(list);
    } catch (e, stack) {
      reportCaught(e, stack);
      if (!_told) {
        _told = true;
        ref.read(decisionsUnsavedProvider.notifier).raise();
      }
    }
  }
}

/// 고른 표시를 폰에 저장하지 못했다 (보이는 화면이 한 번 알리고 내린다)
final decisionsUnsavedProvider = NotifierProvider<OneShotNotifier, bool>(
  OneShotNotifier.new,
);

final decisionsProvider =
    AsyncNotifierProvider<DecisionsNotifier, Map<String, Decision>>(
      DecisionsNotifier.new,
    );

/// 사진의 결정 상태. 예전에 저장된 보류는 표시 없음(undecided)으로 본다.
DecisionState stateOf(Map<String, Decision> decisions, String id) {
  final s = decisions[id]?.state;
  return s == null || s == DecisionState.hold ? DecisionState.undecided : s;
}
