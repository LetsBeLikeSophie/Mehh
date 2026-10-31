part of 'sort_screen.dart';

/// Cortex로 보내기·받았어요 신호·받으러 가기
extension _Cortex on _SortScreenState {
  /// Cortex가 "받았어요"(파일을 자기 쪽에 복사함) 신호를 보내면, 받았다고 알리고
  /// 휴지통으로 보낼지 묻는다. 분석은 그 뒤 Cortex가 혼자 한다 (2026-10-24 Sophie)
  void _onCortexSaved(CortexSaved saved) {
    if (!mounted) return;
    final last = _sentToCortex;
    if (saved.ids case final savedIds?) {
      // 받은 사진 목록이 오면 기다리는 사진(cortex_sent, 아직 못 받음) 중 받은 것만 묻는다.
      // 기다리는 동안 또 보내도 묶음이 섞이지 않는다 (시니어 리뷰 2026-10-24 S-3)
      final waiting = ref.read(cortexSentProvider).value ?? const {};
      final done = [
        for (final id in savedIds)
          if (waiting[id] == false) id,
      ];
      if (done.isEmpty) {
        // 마지막으로 보낸 것을 하나도 못 받았다고 알려 온 경우만 알린다
        if (last != null && savedIds.isEmpty) {
          _sentToCortex = null;
          showNote(context, context.l.cortexPartial(0));
        }
        return;
      }
      final fromLast = last != null && done.every(last.contains);
      if (fromLast) _sentToCortex = null;
      _askTrashAfterCortex(
        done,
        kept: fromLast ? last.length - done.length : 0,
      );
      return;
    }
    // 장수만 오면(예전 Cortex) 마지막으로 보낸 묶음과 견줘, 다 받았을 때만 묻는다 (S-2)
    if (last == null) return;
    _sentToCortex = null;
    if (saved.count < last.length) {
      showNote(context, context.l.cortexPartial(saved.count));
      return;
    }
    _askTrashAfterCortex(last);
  }

  /// "✓ Cortex가 N장 받았어요 · 분석은 뒤에서 · 휴지통으로 보낼까요?" → 안드로이드 휴지통 확인 창
  /// [나중에]면 X는 그대로, 사진에 "Cortex로 보냄" 표시가 남는다
  Future<void> _askTrashAfterCortex(List<String> ids, {int kept = 0}) async {
    // 받은 것은 다 "Cortex에 있음". 휴지통으로는 지금도 X인 사진만 (보낸 뒤 X를 끄면 킵, 리뷰 2026-10-31 S-1)
    await ref.read(cortexSentProvider.notifier).add(ids, got: true);
    if (!mounted) return;
    final live = _stillMarked(ids);
    if (live.isEmpty) return;
    final l = context.l;
    final ok = await askMehh(
      context,
      title: l.cortexGotTitle(ids.length),
      body: [
        l.cortexGotBody,
        if (kept > 0) l.cortexGotKept(kept),
        if (live.length < ids.length)
          l.cortexGotUnmarked(ids.length - live.length),
      ].join('\n'),
      no: l.later,
      yes: l.toTrash,
    );
    if (!ok || !mounted) return;
    // 창이 떠 있는 동안 X를 바꿨을 수도 있어서 한 번 더 본다
    final now = _stillMarked(live);
    if (now.isEmpty) return;
    final src = _src;
    if (src == null) {
      await sendToTrash(context, ref, now);
    } else {
      await _trashAndAfter(now, src, _order);
    }
  }

  /// [ids] 중 지금 X(정리할 사진)인 것
  List<String> _stillMarked(List<String> ids) {
    final decisions = ref.read(decisionsProvider).value ?? const {};
    final src = _src ?? const SortSource(photos: []);
    return [
      for (final id in ids)
        if (isMarked(id, decisions, src)) id,
    ];
  }

  /// 여러 장을 한 번에 Cortex로 보낸다. Cortex가 받으면 지울지 묻고, 분석은 Cortex가 뒤에서.
  Future<void> _sendCortex(List<String> ids) async {
    // 매번 한 줄로 묻는다: "N장을 Cortex로 보낼까요?" (UX-43, 2026-10-24 Sophie: 지우기는 받은 뒤에 묻는다)
    final l = context.l;
    final sent = ref.read(cortexSentProvider).value ?? const {};
    // 고른 사진은 다 보낸다. 전에 보낸 사진이 섞여 있으면 한 줄로 알린다(UX-57).
    // Cortex에서 지웠을 수도 있어서 Mehh가 빼지 않는다 (2026-10-30 Sophie, C3-B 대신)
    final again = ids.where(sent.containsKey).length;
    final ok = await askMehh(
      context,
      title: l.cortexAskTitle(ids.length),
      // 사진이 AI 앱으로 간다는 것만 한 줄 (2026-10-24 Sophie). 키마다 한 줄
      body: [
        l.cortexAskNote,
        if (again > 0) l.cortexAskResend(again),
      ].join('\n'),
      no: l.cancel,
      yes: l.cortexAskYes,
    );
    if (!ok || !mounted) return;
    _set(() => _busy = true);
    final r = await ref.read(handoffProvider).sendManyToCortex(ids);
    if (!mounted) return;
    switch (r) {
      case SendResult.ok:
        // Cortex가 받았다고 알려 오면 지울지 묻는다 (안 알려 오면 그대로 둔다)
        _savedSub ??= ref
            .read(handoffProvider)
            .cortexSaved
            .listen(_onCortexSaved);
        _sentToCortex = ids;
        // 받았다는 신호가 올 때까지 "Cortex로 보냄" 표시. 기다리는 동안 버튼은 잠그지 않는다
        await ref.read(cortexSentProvider.notifier).add(ids);
        if (mounted) _set(() => _busy = false);
      case SendResult.unsupported:
        _set(() => _busy = false);
        showNote(context, l.cortexMultiUnsupported);
      case SendResult.failed:
        _set(() => _busy = false);
        showNote(context, l.cortexFailed);
    }
  }

  /// Cortex가 없을 때: 무슨 앱인지 한 줄 + [받으러 가기] → 스토어
  Future<void> _getCortex() async {
    final l = context.l;
    final ok = await askMehh(
      context,
      title: l.cortexGetTitle,
      body: l.cortexGetBody,
      no: l.cancel,
      yes: l.cortexGetYes,
    );
    if (!ok) return;
    await launchUrl(
      Uri.parse(cortexStoreUrl),
      mode: LaunchMode.externalApplication,
    );
  }
}
