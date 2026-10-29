part of 'sort_screen.dart';

/// 휴지통으로 보내기와 그 뒤 기록(추천 정확도·다 봤어요·Pro 안내)
extension _Trash on _SortScreenState {
  /// 그리드 어디든 길게 눌러 동그라미가 다 차면: 지금 선택한 사진 기준으로 묻고,
  /// 보내면 이 묶음을 끝내고 나간다 (2026-10-24 Sophie)
  Future<void> _finishHere(
    List<String> marked,
    SortSource src,
    List<String> order,
  ) async {
    final l = context.l;
    final n = marked.length;
    final ok = await askMehh(
      context,
      // 제목 = 아래 버튼과 같은 말 "N장 휴지통으로" (2026-10-24 Sophie: 반복되는 말 없이)
      title: n > 0
          ? _trashCount(l, n)
          : widget.kind == SortKind.videos
          ? l.focusFinishNoneVideos
          : l.focusFinishNone,
      no: l.focusKeepLooking,
      yes: n > 0 ? l.toTrash : l.focusFinishYes,
    );
    if (!ok || !mounted) return;
    if (n > 0 && !await _send(marked, src, order)) return;
    if (!mounted) return;
    // 이 정리 화면만 닫는다. Pro 안내에서 "지금 무료로"를 눌러 다른 화면이 위에 열렸으면
    // 그 화면은 두고 아래의 이 화면만 뺀다 (UX-52: maybePop이 새로 연 캡처 화면을 닫았다)
    final route = ModalRoute.of(context);
    final nav = Navigator.of(context);
    if (route == null || route.isCurrent) {
      await nav.maybePop();
    } else if (route.isActive) {
      nav.removeRoute(route);
    }
  }

  /// 반환: 실제로 휴지통으로 보냈는지
  Future<bool> _send(
    List<String> ids,
    SortSource src,
    List<String> shown,
  ) async {
    if (!await _confirmSceneLoss(ids, src) || !mounted) return false;
    return _trashAndAfter(ids, src, shown);
  }

  /// 휴지통으로 보내고 그 뒤 할 일: 정확도 기록, 잠긴 묶음 "다 봤어요"(R3), Pro 안내.
  /// [N장 휴지통으로]와 Cortex 길이 같이 쓴다 (시니어 리뷰 2026-10-24 S-2)
  /// "N장 휴지통으로" — 큰 동영상은 "N개" (홈 줄과 같은 단위)
  String _trashCount(L10n l, int n) =>
      widget.kind == SortKind.videos ? l.trashCountVideos(n) : l.trashCount(n);

  Future<bool> _trashAndAfter(
    List<String> ids,
    SortSource src,
    List<String> shown,
  ) async {
    final markedBefore = _markedNow; // 보내면 다시 그려져 바뀌므로 먼저 잡아 둔다
    _set(() => _busy = true);
    // 정리를 끝낸 순간에 Pro 안내 (Pro가 아니면 하루 한 번까지). 안내 시트가 아래 알림을 덮으니
    // 그때는 알림 대신 시트 첫 줄에 "30일 안에 되살릴 수 있어요"까지 넣는다 (UX 리뷰 2026-10-22)
    final pro = ref.read(proProvider.notifier);
    final nudge = widget.kind == SortKind.day && await pro.canNudge();
    if (!mounted) return false;
    final n = await sendToTrash(
      context,
      ref,
      ids,
      quiet: nudge,
      doneNote: widget.kind == SortKind.videos
          ? (n, size) => context.l.trashedVideos(n, size)
          : null,
    );
    if (n > 0) await _recordPicks(ids, src, shown, markedBefore);
    // 잠긴 묶음을 직접 정리해 보냈으면 다음부터 "다 봤어요" (2026-10-22 Sophie R3-A)
    if (n > 0 && src.locked > 0) {
      final sent = ids.toSet();
      await ref
          .read(seenProvider.notifier)
          .mark(shown.where((id) => !sent.contains(id)));
    }
    if (mounted) _set(() => _busy = false);
    if (n > 0 && nudge && await pro.takeNudge() && mounted) {
      await showProSheet(context, lead: context.l.proNudge(n));
    }
    return n > 0;
  }

  /// 추천 정확도 기록 (SPEC 6-8). [추천 보기]를 눌렀거나 처음부터 X인 추천이 있을 때만 센다.
  Future<void> _recordPicks(
    List<String> sent,
    SortSource src,
    List<String> shown,
    Set<String> marked,
  ) async {
    // 사용자에게 X로 보였던 추천만 센다: [추천 보기]로 받은 것 + 처음부터 X였던 것.
    // 보지 못한 추천을 "거절"로 세면 취향 학습이 멀쩡한 추천을 끈다 (시니어 리뷰 2026-10-23 S-1)
    // 화면을 나갔다 와서 _picked가 비어도, 손으로 고르지 않았는데 X인 추천이 있으면 [추천 보기]가
    // 켜져 있던 것: 그 추천 전체를 보인 추천으로 센다(잠긴 묶음 제외, S-1 2026-10-27)
    // 지금 X인 추천만 보인 추천으로 (그 사이 새로 생긴 추천은 X로 보인 적이 없다, UX-61)
    final shownPicks = {
      ..._picked,
      ..._preMarkedSeen,
      ...src.preMarked,
      if (src.locked == 0 && _picksTurnedOn(src, marked))
        ...src.suggested.where(marked.contains),
    };
    if (shownPicks.isEmpty) return;
    await ref
        .read(storeProvider)
        .addPicks(
          pickRecords(
            at: DateTime.now(),
            kind: widget.kind.name,
            shown: shown,
            sent: sent.toSet(),
            suggested: shownPicks,
            tags: {
              ..._seenTags,
              for (final e in src.tags.entries) e.key: e.value.name,
            },
          ),
        );
    // 기록이 쌓였으니 자주 되돌린 이유를 다시 계산 (취향 학습). 새로 꺼진 이유는 한 줄로 알린다 (L1-B)
    final before = ref.read(mutedReasonsProvider).value ?? const {};
    ref.invalidate(mutedReasonsProvider);
    final after = await ref.read(mutedReasonsProvider.future);
    final newly = after.difference(before);
    if (newly.isNotEmpty && mounted) {
      final l = context.l;
      showNote(
        context,
        [
          for (final r in newly)
            switch (r) {
              TrashReason.burst => l.mutedBurst,
              TrashReason.blurry => l.mutedBlurry,
              TrashReason.junk => l.mutedJunk,
              TrashReason.eyesClosed => l.mutedEyesClosed,
            },
        ].join('\n'),
      );
    }
  }

  /// 연속 컷·중복 묶음이 통째로 사라지면 한 번 묻는다 (묶음마다 최소 1장)
  Future<bool> _confirmSceneLoss(List<String> ids, SortSource src) async {
    final decisions = ref.read(decisionsProvider).value ?? const {};
    final sending = ids.toSet();
    final emptied = src.units.where(
      (u) => u.every(
        (id) =>
            sending.contains(id) ||
            stateOf(decisions, id) == DecisionState.trashed,
      ),
    );
    if (emptied.isEmpty) return true;
    final l = context.l;
    return askMehh(
      context,
      title: l.sceneLossTitle(emptied.length),
      body: l.sceneLossBody,
      no: l.lookAgain,
      yes: l.toTrash,
    );
  }
}
