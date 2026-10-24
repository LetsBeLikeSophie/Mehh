import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/handoff.dart';
import '../data/pro.dart';
import '../l10n/l10n.dart';
import '../logic/format.dart';
import '../logic/pick_stats.dart';
import '../logic/recommend.dart';
import '../models/day_group.dart';
import '../models/decision.dart';
import '../models/photo_meta.dart';
import '../providers.dart';
import '../theme.dart';
import 'pro_sheet.dart';
import 'focus_screen.dart';
import 'freed_bar.dart';
import 'hold_to_finish.dart';
import 'sort_source.dart';
import 'trash_flow.dart';
import 'widgets.dart';

export 'sort_source.dart' show SortKind;

/// 정리 화면: 앨범처럼 한눈에 보는 그리드.
///
/// 위쪽: 제목·장수, 그 아래 한 줄 [추천 보기 · N장] [Cortex로 보내기(캡처)] … [전체 선택].
/// 앱 추천은 [추천 보기]를 눌러야 X로 들어간다 (그날의 묶음은 무료 묶음·Pro로 연다).
/// X를 누르면 정리 ↔ 킵, 사진을 누르면 크게 보기([FocusScreen]).
/// 묶음, 낱장 사진, 캡처, 똑같은 사진 모두 이 화면을 쓴다.
class SortScreen extends ConsumerStatefulWidget {
  const SortScreen({super.key, required this.kind, this.group, this.place});

  final SortKind kind;

  /// [SortKind.duplicates]가 아니면 필요
  final DayGroup? group;
  final String? place;

  @override
  ConsumerState<SortScreen> createState() => _SortScreenState();
}

class _SortScreenState extends ConsumerState<SortScreen>
    with WidgetsBindingObserver {
  bool _busy = false;

  /// 이번에 [추천 보기]로 X를 친 사진 (추천 정확도는 추천을 본 경우만, 이 목록으로 센다.
  /// 나중에 X를 꺼서 킵하면 추천에서 빠지므로, 누른 순간의 목록을 기억한다)
  final _picked = <String>{};

  /// 화면에 보였던 이유 표시 (킵해서 사라진 표시도 기록에 남기려고)
  final _seenTags = <String, String>{};

  /// 처음부터 X로 보였던 사진 (끄면 킵이 되어 목록에서 빠지므로 기억해 둔다)
  final _preMarkedSeen = <String>{};

  /// Cortex로 보낸 캡처. Cortex가 다 읽은 뒤(Mehh로 돌아왔을 때) 휴지통으로 옮긴다.
  List<String>? _sentToCortex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _savedSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  StreamSubscription<CortexSaved>? _savedSub;

  /// Cortex에서 돌아왔는데 "저장 완료" 신호가 없으면, 조금 기다렸다가 옮기지 않고 알린다
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _sentToCortex == null) return;
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      final sent = _sentToCortex;
      if (!mounted || sent == null) return;
      _sentToCortex = null;
      setState(() => _busy = false);
      showNote(context, context.l.cortexNotSaved(sent.length));
    });
  }

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
  /// [나중에]면 X는 그대로, 사진에 "Cortex에 있음" 표시가 남는다
  Future<void> _askTrashAfterCortex(List<String> ids, {int kept = 0}) async {
    await ref.read(cortexSentProvider.notifier).add(ids, got: true);
    if (!mounted) return;
    final l = context.l;
    final ok = await askMehh(
      context,
      title: l.cortexGotTitle(ids.length),
      body: kept > 0
          ? '${l.cortexGotBody}\n${l.cortexGotKept(kept)}'
          : l.cortexGotBody,
      no: l.later,
      yes: l.toTrash,
    );
    if (!ok || !mounted) return;
    final src = _src;
    if (src == null) {
      await sendToTrash(context, ref, ids);
    } else {
      await _trashAndAfter(ids, src, _order);
    }
  }

  /// 여러 장을 한 번에 Cortex로 보낸다. Cortex가 받으면 지울지 묻고, 분석은 Cortex가 뒤에서.
  Future<void> _sendCortex(List<String> ids) async {
    // 매번 한 줄로 묻는다: "N장을 Cortex로 보낼까요?" (UX-43, 2026-10-24 Sophie: 지우기는 받은 뒤에 묻는다)
    final l = context.l;
    final ok = await askMehh(
      context,
      title: l.cortexAskTitle(ids.length),
      // 사진이 AI 앱으로 간다는 것만 한 줄 (2026-10-24 Sophie)
      body: l.cortexAskNote,
      no: l.cancel,
      yes: l.cortexAskYes,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
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
        if (mounted) setState(() => _busy = false);
      case SendResult.unsupported:
        setState(() => _busy = false);
        showNote(context, l.cortexMultiUnsupported);
      case SendResult.failed:
        setState(() => _busy = false);
        showNote(context, l.cortexFailed);
    }
  }

  Future<void> _toggle(String id, bool marked) => ref
      .read(decisionsProvider.notifier)
      .set([id], marked ? DecisionState.keep : DecisionState.toTrash);

  /// [전체 선택] = 모두 X
  Future<void> _selectAll(List<String> ids) =>
      ref.read(decisionsProvider.notifier).set(ids, DecisionState.toTrash);

  /// [선택 해제] = 모두 표시 없음 (처음 상태). 추천이 지워지지 않아 [추천 보기]로 다시 받을 수 있다.
  /// 처음부터 X로 보이는 사진(preMarked)만은 킵으로 저장해야 X가 꺼진다 (2026-10-22 Sophie R2-A)
  Future<void> _clearAll(List<String> ids, SortSource src) async {
    final notifier = ref.read(decisionsProvider.notifier);
    await notifier.restore({
      for (final id in ids)
        if (!src.preMarked.contains(id)) id: null,
    });
    await notifier.set([
      for (final id in ids)
        if (src.preMarked.contains(id)) id,
    ], DecisionState.keep);
  }

  /// [추천 보기]: 앱이 고른 사진에 X를 친다. 그날의 묶음은 이번 달 무료 묶음이나 Pro로 열고,
  /// 다 썼으면 Pro 안내. 다시 누르면 추천대로 다시 X.
  // ───────────────────────── 끌어서 여러 장 선택

  final _gridKey = GlobalKey();

  /// 지금 X인 사진 (마지막 build 기준)
  Set<String> _markedNow = const {};

  /// 이번 끌기에서 바꿀 상태 (첫 사진의 반대) · 이미 바꾼 사진
  bool? _paintTo;
  final _painted = <String>{};

  String? _photoAt(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final result = BoxHitTestResult();
    box.hitTest(result, position: box.globalToLocal(global));
    for (final e in result.path) {
      final t = e.target;
      if (t is RenderMetaData && t.metaData is String) {
        return t.metaData as String;
      }
    }
    return null;
  }

  /// 가장자리에서 시작한 끌기: 사진 선택 대신 뒤로 가기 (2026-10-24 Sophie: 캡처 묶음에서 스와이프로
  /// 뒤로 안 갔다 — 사진이 화면을 꽉 채워 끌어 선택이 먼저 잡혔다)
  Offset? _edgeFrom;
  double _edgeDx = 0;

  void _paintStart(Offset global) {
    final width = MediaQuery.sizeOf(context).width;
    if (global.dx < backEdge || global.dx > width - backEdge) {
      _edgeFrom = global;
      _edgeDx = 0;
      return;
    }
    final id = _photoAt(global);
    if (id == null) return;
    _painted.clear();
    _paintTo = !_markedNow.contains(id);
    _paint(id);
  }

  void _paintMove(Offset global) {
    if (_edgeFrom case final from?) {
      _edgeDx = global.dx - from.dx;
      return;
    }
    if (_paintTo == null) return;
    final id = _photoAt(global);
    if (id == null || id == _paintLast) return;
    // 빨리 끌어 건너뛴 사진도: 화면 순서로 지난 사진과 지금 사진 사이를 모두
    final a = _order.indexOf(_paintLast ?? id), b = _order.indexOf(id);
    if (a < 0 || b < 0) {
      if (!_painted.contains(id)) _paint(id);
    } else {
      for (var i = a < b ? a : b; i <= (a < b ? b : a); i++) {
        if (!_painted.contains(_order[i])) _paint(_order[i]);
      }
    }
    _paintLast = id;
  }

  String? _paintLast;

  void _paint(String id) {
    _painted.add(id);
    _paintLast = id;
    // X 버튼과 같은 결과: 켜면 정리(X), 끄면 킵
    ref.read(decisionsProvider.notifier).set([
      id,
    ], _paintTo! ? DecisionState.toTrash : DecisionState.keep);
  }

  void _paintEnd(double? velocity) {
    // 가장자리에서 안쪽으로 충분히(또는 빠르게) 밀었으면 뒤로
    if (_edgeFrom != null &&
        (_edgeDx.abs() > backSwipeDistance || (velocity ?? 0).abs() > 600)) {
      _edgeFrom = null;
      Navigator.of(context).maybePop();
      return;
    }
    _edgeFrom = null;
    _paintTo = null;
    _paintLast = null;
    _painted.clear();
  }

  Future<void> _rename(DayGroup g) async {
    final original = sortTitle(widget.kind, g, widget.place, context.l);
    final v = await askGroupName(
      context,
      current: ref.read(groupNamesProvider).value?[g.id] ?? original,
      original: original,
    );
    if (v != null) {
      await ref.read(groupNamesProvider.notifier).rename(g.id, v);
    }
  }

  /// 켜 둔 추천 끄기: 추천으로 들어간 X만 표시 없음으로 (직접 선택한 다른 사진은 그대로).
  /// 실수 사진처럼 처음부터 X인 것은 표시 없음이어도 X로 보인다
  Future<void> _hidePicks(SortSource src) async {
    await ref.read(decisionsProvider.notifier).restore({
      for (final id in src.suggested) id: null,
    });
    if (mounted) setState(() => _picked.removeAll(src.suggested));
  }

  Future<void> _showPicks(SortSource src) async {
    final g = widget.group;
    final pro = ref.read(proProvider.notifier);
    // 그날의 묶음은 열려 있어도 늘 unlock을 부른다: Pro면 사진만 기억해서
    // 1년 이용권이 끝나도 계속 열려 있게 한다 (F3-A, UX 리뷰 2026-10-23 UX-35)
    final proNow = (await ref.read(proProvider.future)).pro;
    // 잠긴 묶음만 무료 묶음·Pro로 연다. 무료 추천(실수 사진)만 있는 묶음은 열 게 없다 (P2-A)
    if (widget.kind == SortKind.day &&
        g != null &&
        (src.locked > 0 || proNow)) {
      final photoIds = [for (final p in g.photos) p.id];
      final now = DateTime.now();
      final freeBefore = (await ref.read(proProvider.future)).freeLeft(now);
      // 무료 묶음을 쓰기 전에 한 번 묻는다 (2026-10-23 Sophie: 버튼 아래 설명 대신)
      if (!proNow && src.locked > 0 && freeBefore > 0) {
        if (!mounted) return;
        final l = context.l;
        final ok = await askMehh(
          context,
          title: l.useFreeSetTitle,
          body: l.useFreeSetBody(src.locked + src.suggested.length),
          // 남은 코인은 제목 옆에 아이콘으로 (2026-10-24 Sophie)
          // 무엇을 쓰는지 코인 그림으로 바로 (2026-10-24 Sophie)
          titleLeading: const CoinIcon(size: 26),
          titleTrailing: CoinCount(freeBefore, size: 18),
          no: l.cancel,
          yes: l.useFreeSetYes,
        );
        if (!ok) return;
      }
      if (!await pro.unlock(g.id, photoIds: photoIds)) {
        if (!mounted) return;
        // 무료를 다 써서 여는 거면 판매 안내 앞에 이유 한 줄 (UX 리뷰 2026-10-23 UX-45)
        await showProSheet(
          context,
          lead: freeBefore == 0
              ? context.l.noFreeLead(
                  formatDate(nextFreeReset(now), context.l.localeName),
                  freeGroupsPerMonth,
                )
              : null,
        );
        // 시트에서 Pro를 샀으면 다시 누르지 않아도 이어서 추천을 X로 (UX 리뷰 2026-10-22).
        // 결제 대기·취소면 그대로 끝
        if (!(ref.read(proProvider).value?.pro ?? false)) return;
        await pro.unlock(g.id, photoIds: photoIds); // Pro로 본 묶음 기억
      }
    }
    // 화면에 보이던 추천을 그대로 X로. 잠겨 있던 묶음만 방금 연 추천을 다시 계산해서 받는다
    // (캡처는 캡처 추천을 써야 한다: 묶음 추천을 쓰면 일부만 X가 됐다, 2026-10-22 버그)
    final ids = src.locked > 0 && g != null
        ? ref.read(groupPlanProvider(g)).trash.keys.toSet()
        : src.suggested;
    final decisions = ref.read(decisionsProvider).value ?? const {};
    await ref.read(decisionsProvider.notifier).set([
      for (final id in ids)
        if (stateOf(decisions, id) != DecisionState.trashed) id,
    ], DecisionState.toTrash);
    if (mounted) setState(() => _picked.addAll(ids));
  }

  /// 크게 보기. 거기서 길게 눌러 "휴지통으로 보내고 끝내기"를 고르면 돌아와서 바로 보낸다
  Future<void> _open(String id) async {
    final send = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FocusScreen(
          kind: widget.kind,
          group: widget.group,
          place: widget.place,
          initialId: id,
        ),
      ),
    );
    if (send != true || !mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) _sendMarked?.call();
  }

  /// 지금 X인 사진을 [N장 휴지통으로]처럼 보낸다 (마지막 build 기준)
  VoidCallback? _sendMarked;

  /// 마지막 build의 추천·화면 순서 (Cortex 신호가 나중에 와도 보낸 뒤 할 일을 하려고)
  SortSource? _src;

  /// 큰 동영상 칸의 길이·용량 표시용
  Map<String, PhotoMeta> _videoMeta = const {};
  List<String> _order = const [];

  /// 반환: 실제로 휴지통으로 보냈는지
  Future<bool> _send(
    List<String> ids,
    SortSource src,
    List<String> shown,
  ) async {
    if (!await _confirmSceneLoss(ids, src) || !mounted) return false;
    return _trashAndAfter(ids, src, shown);
  }

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
      title: n > 0 ? l.trashCount(n) : l.focusFinishNone,
      no: l.focusKeepLooking,
      yes: n > 0 ? l.toTrash : l.focusFinishYes,
    );
    if (!ok || !mounted) return;
    if (n > 0 && !await _send(marked, src, order)) return;
    if (mounted) await Navigator.of(context).maybePop();
  }

  /// 휴지통으로 보내고 그 뒤 할 일: 정확도 기록, 잠긴 묶음 "다 봤어요"(R3), Pro 안내.
  /// [N장 휴지통으로]와 Cortex 길이 같이 쓴다 (시니어 리뷰 2026-10-24 S-2)
  Future<bool> _trashAndAfter(
    List<String> ids,
    SortSource src,
    List<String> shown,
  ) async {
    setState(() => _busy = true);
    // 정리를 끝낸 순간에 Pro 안내 (Pro가 아니면 하루 한 번까지). 안내 시트가 아래 알림을 덮으니
    // 그때는 알림 대신 시트 첫 줄에 "30일 안에 되살릴 수 있어요"까지 넣는다 (UX 리뷰 2026-10-22)
    final pro = ref.read(proProvider.notifier);
    final nudge = widget.kind == SortKind.day && await pro.canNudge();
    if (!mounted) return false;
    final n = await sendToTrash(context, ref, ids, quiet: nudge);
    if (n > 0) await _recordPicks(ids, src, shown);
    // 잠긴 묶음을 직접 정리해 보냈으면 다음부터 "다 봤어요" (2026-10-22 Sophie R3-A)
    if (n > 0 && src.locked > 0) {
      final sent = ids.toSet();
      await ref
          .read(seenProvider.notifier)
          .mark(shown.where((id) => !sent.contains(id)));
    }
    if (mounted) setState(() => _busy = false);
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
  ) async {
    // 사용자에게 X로 보였던 추천만 센다: [추천 보기]로 받은 것 + 처음부터 X였던 것.
    // 보지 못한 추천을 "거절"로 세면 취향 학습이 멀쩡한 추천을 끈다 (시니어 리뷰 2026-10-23 S-1)
    final shownPicks = {..._picked, ..._preMarkedSeen, ...src.preMarked};
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

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final src = watchSortSource(ref, widget.kind, widget.group);
    for (final e in src.tags.entries) {
      _seenTags[e.key] = e.value.name;
    }
    _preMarkedSeen.addAll(src.preMarked);
    // Cortex로 보내기는 모든 종류에서 같은 자리 (2026-10-24 Sophie)
    final cortex = ref.watch(cortexInstalledProvider).value ?? false;
    final decisions = ref.watch(decisionsProvider).value ?? const {};
    final entities = ref.read(photoLibraryProvider).entities;
    final order = [
      for (final p in src.photos)
        if (stateOf(decisions, p.id) != DecisionState.trashed) p.id,
    ];
    final marked = [
      for (final id in order)
        if (isMarked(id, decisions, src)) id,
    ];
    final allSelected = order.isNotEmpty && marked.length == order.length;
    // [추천 보기]는 켜고 끄는 버튼 (2026-10-24 Sophie). 켠 상태 = 이 화면에서 [추천 보기]를 눌렀고
    // 추천이 모두 X. 끈 상태 = 처음 상태(실수 사진처럼 처음부터 X인 것만 X)
    final markedSet = marked.toSet();
    _markedNow = markedSet;
    final picksOn =
        src.locked == 0 &&
        src.suggested.any(_picked.contains) &&
        src.suggested.every(markedSet.contains);
    // 앱이 고른 추천 장수 (잠긴 묶음은 열기 전 장수)
    // [추천 보기 · N장]의 N = 누르면 X가 되는 장수 (잠긴 추천 + 이미 X로 보이는 실수 사진).
    // 66장이라 해 놓고 78장이 X가 되던 것 (2026-10-24 Sophie 버그)
    final picks = src.locked > 0
        ? src.locked + src.suggested.length
        : src.suggested.length;
    final sections = widget.kind == SortKind.duplicates
        ? [
            for (final u in src.units)
              [
                for (final id in u)
                  if (order.contains(id)) id,
              ],
          ].where((u) => u.isNotEmpty).toList()
        : [order];

    final cortexSent =
        ref.watch(cortexSentProvider).value ?? const <String, bool>{};

    Widget tile(String id) {
      final out = marked.contains(id);
      // 이유 표시는 X가 쳐진 사진에만 ("왜 X인지"). 남길 사진·베스트는 추천을 받은 뒤에만 (2026-10-22)
      final t = src.tags[id];
      final keepTag = t == PhotoTag.best || t == PhotoTag.original;
      final tag = keepTag
          ? (_picked.isNotEmpty || src.preMarked.isNotEmpty ? t : null)
          : (out ? t : null);
      return MetaData(
        metaData: id,
        behavior: HitTestBehavior.translucent,
        child: GestureDetector(
          onTap: () => _open(id),
          child: Semantics(
            button: true,
            label: out ? l.markedPhoto : l.photo,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: out ? 0.45 : 1,
                  child: PhotoThumb(entity: entities[id]),
                ),
                if (tag != null)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: MehhBadge(tagText(tag, l), inverted: out),
                  ),
                // 큰 동영상: 길이 · 용량
                if (_videoMeta[id] case final v?)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    right: 4,
                    child: IgnorePointer(
                      child: Align(
                        alignment: AlignmentDirectional.bottomStart,
                        child: MehhBadge(
                          '${formatDuration(v.durationSec)} · ${formatBytes(v.sizeBytes)}',
                          inverted: out,
                        ),
                      ),
                    ),
                  ),
                // Cortex로 보낸 사진: 받았는지까지 보이게 (어디서 멈췄는지 알 수 있게).
                // X 버튼 아래에 깔고 누르기를 막지 않는다 (작은 칸에서 X를 덮지 않게)
                if (cortexSent[id] case final got?)
                  Positioned(
                    left: 4,
                    top: 4,
                    right: 4,
                    child: IgnorePointer(
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: MehhBadge(
                          got ? l.cortexGotBadge : l.cortexSentBadge,
                          inverted: out,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: XToggle(on: out, onTap: () => _toggle(id, out)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final g = widget.group;
    final range = widget.kind == SortKind.day && g != null
        ? groupTimeRange(g, l)
        : null;
    final subLine = src.analyzing
        ? (range == null
              ? l.analyzingShort
              : l.countAndRange(range, l.analyzingShort))
        : range;

    _sendMarked = marked.isEmpty ? null : () => _send(marked, src, order);
    _src = src;
    _order = order;
    _videoMeta = {
      for (final p in src.photos)
        if (p.isVideo) p.id: p,
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // 길게 누르기 = 정리 끝내기 (크게 보기와 같은 [HoldToFinish])
              child: HoldToFinish(
                armed: marked.isNotEmpty,
                onDone: () => _finishHere(marked, src, order),
                // 옆으로 끌기 시작하면 지나가는 사진을 한꺼번에 선택(또는 해제). 위아래는 그대로 스크롤
                // (2026-10-24 Sophie: 드래그로 여러 장)
                child: GestureDetector(
                  key: _gridKey,
                  behavior: HitTestBehavior.translucent,
                  // 손가락을 댄 자리부터 본다: 화면 가장자리에서 시작하면 뒤로 가기
                  dragStartBehavior: DragStartBehavior.down,
                  onHorizontalDragStart: (d) => _paintStart(d.globalPosition),
                  onHorizontalDragUpdate: (d) => _paintMove(d.globalPosition),
                  onHorizontalDragEnd: (d) => _paintEnd(d.primaryVelocity),
                  onHorizontalDragCancel: () => _paintEnd(null),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                        sliver: SliverList.list(
                          children: [
                            // 맨 위 줄·제목 칸은 홈과 같은 높이: 막대가 같은 자리에 온다 (2026-10-24 Sophie)
                            MehhHeader.top(
                              leading: const MehhBackButton(),
                              trailing: const [MehhTopActions()],
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 12,
                                end: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MehhHeader.titleBox([
                                    // 제목 뒤에 장수 (2026-10-23 Sophie: 장수가 따로 한 줄을 차지하지 않게)
                                    // 제목을 누르면 이름 바꾸기 (그날의 묶음·낱장·캡처)
                                    GestureDetector(
                                      onTap: g == null
                                          ? null
                                          : () => _rename(g),
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text:
                                                  ref
                                                      .watch(groupNamesProvider)
                                                      .value?[g?.id] ??
                                                  sortTitle(
                                                    widget.kind,
                                                    g,
                                                    widget.place,
                                                    l,
                                                  ),
                                            ),
                                            TextSpan(
                                              text:
                                                  '  ${l.photos(order.length)}',
                                              style: const TextStyle(
                                                fontSize: MehhText.bodySmall,
                                                fontWeight: FontWeight.w500,
                                                color: MehhColors.textMuted,
                                                letterSpacing: 0,
                                              ),
                                            ),
                                          ],
                                        ),
                                        style: const TextStyle(
                                          fontSize: MehhText.title,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ),
                                    if (subLine != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        subLine,
                                        style: const TextStyle(
                                          fontSize: MehhText.bodySmall,
                                          color: MehhColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ]),
                                  // 홈과 같은 막대·같은 뜻: 선택하면 추천 정리(연한 코랄)가 선택(코랄)으로, 보내면 휴지통으로
                                  // 이 묶음에서 선택한 것만 코랄 (전체 기준 아님)
                                  FreedBar(selected: marked),
                                  const SizedBox(height: 12),
                                  Row(
                                    // 버튼은 글자 길이만큼, 자리가 모자랄 때만 줄인다 (가운데 빈칸 없이 양 끝으로)
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (picks > 0)
                                        Flexible(
                                          // 켠 상태는 ✓와 테두리로 보인다(X처럼 켜고 끄는 표시). 끄면 추천 X만 풀린다
                                          // 모양은 늘 같고, 앞 칸만 바뀐다: 잠김 → 자물쇠, 끔 → 빈 체크 칸, 켬 → 체크 (2026-10-24 Sophie)
                                          child: _PillButton(
                                            label: l.showPicks(picks),
                                            icon: src.locked > 0
                                                ? Icons.lock_outline
                                                : picksOn
                                                ? Icons.check_box
                                                : Icons.check_box_outline_blank,
                                            filled: true,
                                            onTap: _busy
                                                ? null
                                                : picksOn
                                                ? () => _hidePicks(src)
                                                : () => _showPicks(src),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: order.isEmpty
                                            ? null
                                            : allSelected
                                            ? () => _clearAll(order, src)
                                            : () => _selectAll(order),
                                        style: TextButton.styleFrom(
                                          foregroundColor: MehhColors.text,
                                          minimumSize: const Size(44, 44),
                                        ),
                                        child: Text(
                                          allSelected
                                              ? l.deselectAll
                                              : l.selectAll,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 똑같은 사진은 묶음마다 새 줄에서 시작해 어떤 사진끼리 같은지 보이게
                      for (final (i, section) in sections.indexed)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            i == sections.length - 1 ? 16 : 14,
                          ),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  mainAxisSpacing: 4,
                                  crossAxisSpacing: 4,
                                ),
                            itemCount: section.length,
                            itemBuilder: (_, j) => tile(section[j]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy || marked.isEmpty
                          ? null
                          : () => _send(marked, src, order),
                      child: Text(
                        marked.isEmpty
                            ? l.nothingMarked
                            : l.trashCount(marked.length),
                        style: const TextStyle(
                          fontSize: MehhText.body,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  // 고른 캡처가 있으면 [휴지통으로] 옆에 작은 Cortex 버튼 (공유하기처럼, 2026-10-23 Sophie)
                  if (cortex && marked.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _sendCortex(marked),
                      icon: const Icon(Icons.north_east, size: 16),
                      label: Text(l.toCortex),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MehhColors.text,
                        minimumSize: const Size(44, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 위쪽 한 줄의 작은 버튼 ([추천 보기 · N장], [Cortex로 보내기])
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    this.onTap,
    this.icon,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(MehhRadius.button),
    );
    const pad = EdgeInsets.symmetric(horizontal: 12);
    const size = Size(44, 36);
    final text = Text(label);
    final iconWidget = icon == null ? null : Icon(icon, size: 16);
    return filled
        ? FilledButton.icon(
            onPressed: onTap,
            icon: iconWidget,
            label: text,
            style: FilledButton.styleFrom(
              backgroundColor: MehhColors.black,
              foregroundColor: MehhColors.white,
              padding: pad,
              minimumSize: size,
              shape: shape,
            ),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: iconWidget,
            label: text,
            style: OutlinedButton.styleFrom(
              foregroundColor: MehhColors.text,
              padding: pad,
              minimumSize: size,
              shape: shape,
            ),
          );
  }
}

/// 홈에서 쓰는 진입 도우미
Route<void> sortRoute(SortKind kind, {DayGroup? group, String? place}) =>
    MaterialPageRoute(
      builder: (_) => SortScreen(kind: kind, group: group, place: place),
    );
