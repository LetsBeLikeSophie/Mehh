import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/handoff.dart';
import '../data/pro.dart';
import '../l10n/l10n.dart';
import '../logic/format.dart';
import '../logic/pick_stats.dart';
import '../logic/recommend.dart';
import '../models/day_group.dart';
import '../models/decision.dart';
import '../providers.dart';
import '../theme.dart';
import 'pro_sheet.dart';
import 'focus_screen.dart';
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

  void _onCortexSaved(CortexSaved saved) {
    final ids = _sentToCortex;
    if (ids == null || !mounted) return;
    _sentToCortex = null;
    // 저장한 사진 목록이 오면 그 사진만 휴지통으로, 나머지는 X 그대로 (C1-B)
    if (saved.ids case final savedIds?) {
      final done = [
        for (final id in ids)
          if (savedIds.contains(id)) id,
      ];
      if (done.isEmpty) {
        setState(() => _busy = false);
        showNote(context, context.l.cortexPartial(0));
        return;
      }
      _trashAfterCortex(done, kept: ids.length - done.length);
      return;
    }
    // 장수만 오면(지금 Cortex) 보낸 장수만큼 저장했을 때만 휴지통으로 (S-2)
    if (saved.count < ids.length) {
      setState(() => _busy = false);
      showNote(context, context.l.cortexPartial(saved.count));
      return;
    }
    _trashAfterCortex(ids);
  }

  /// 여러 장을 한 번에 Cortex로 보낸다. 분석은 Cortex가 하고, 보낸 캡처는 휴지통으로.
  Future<void> _sendCortex(List<String> ids) async {
    // 매번 한 줄로 묻는다: "보내고 지울까요?" (UX-43, 2026-10-23 Sophie: 설명 없이 한 번에, 매번)
    final l = context.l;
    final ok = await askMehh(
      context,
      title: l.cortexAskTitle(ids.length),
      no: l.cancel,
      yes: l.cortexAskYes,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(handoffProvider).sendManyToCortex(ids);
    if (!mounted) return;
    switch (r) {
      case SendResult.ok:
        // Cortex가 저장을 마쳤다고 알려 오면 휴지통으로 (안 알려 오면 그대로 둔다)
        _savedSub ??= ref
            .read(handoffProvider)
            .cortexSaved
            .listen(_onCortexSaved);
        _sentToCortex = ids;
      case SendResult.unsupported:
        setState(() => _busy = false);
        showNote(context, l.cortexMultiUnsupported);
      case SendResult.failed:
        setState(() => _busy = false);
        showNote(context, l.cortexFailed);
    }
  }

  Future<void> _trashAfterCortex(List<String> ids, {int kept = 0}) async {
    await sendToTrash(
      context,
      ref,
      ids,
      doneNote: (n) => kept == 0
          ? context.l.cortexSentTrashed(n)
          : context.l.cortexSentSomeTrashed(n, kept),
    );
    if (mounted) setState(() => _busy = false);
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
          body: l.useFreeSetBody(src.locked, freeBefore),
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

  void _open(String id) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FocusScreen(
        kind: widget.kind,
        group: widget.group,
        place: widget.place,
        initialId: id,
      ),
    ),
  );

  Future<void> _send(
    List<String> ids,
    SortSource src,
    List<String> shown,
  ) async {
    if (!await _confirmSceneLoss(ids, src) || !mounted) return;
    setState(() => _busy = true);
    // 정리를 끝낸 순간에 Pro 안내 (Pro가 아니면 하루 한 번까지). 안내 시트가 아래 알림을 덮으니
    // 그때는 알림 대신 시트 첫 줄에 "30일 안에 되살릴 수 있어요"까지 넣는다 (UX 리뷰 2026-10-22)
    final pro = ref.read(proProvider.notifier);
    final nudge = widget.kind == SortKind.day && await pro.canNudge();
    if (!mounted) return;
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
    final cortex =
        widget.kind == SortKind.screenshots &&
        (ref.watch(cortexInstalledProvider).value ?? false);
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
    // 앱이 고른 추천 장수 (잠긴 묶음은 열기 전 장수)
    final picks = src.locked > 0 ? src.locked : src.suggested.length;
    final sections = widget.kind == SortKind.duplicates
        ? [
            for (final u in src.units)
              [
                for (final id in u)
                  if (order.contains(id)) id,
              ],
          ].where((u) => u.isNotEmpty).toList()
        : [order];

    Widget tile(String id) {
      final out = marked.contains(id);
      // 이유 표시는 X가 쳐진 사진에만 ("왜 X인지"). 남길 사진·베스트는 추천을 받은 뒤에만 (2026-10-22)
      final t = src.tags[id];
      final keepTag = t == PhotoTag.best || t == PhotoTag.original;
      final tag = keepTag
          ? (_picked.isNotEmpty || src.preMarked.isNotEmpty ? t : null)
          : (out ? t : null);
      return GestureDetector(
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
              Positioned(
                right: 0,
                top: 0,
                child: XToggle(on: out, onTap: () => _toggle(id, out)),
              ),
              if (tag != null)
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: MehhBadge(tagText(tag, l), inverted: out),
                ),
            ],
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                    sliver: SliverList.list(
                      children: [
                        const MehhBackButton(),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 제목 뒤에 장수 (2026-10-23 Sophie: 장수가 따로 한 줄을 차지하지 않게)
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: sortTitle(
                                        widget.kind,
                                        g,
                                        widget.place,
                                        l,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '  ${l.photos(order.length)}',
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
                              const SizedBox(height: 12),
                              Row(
                                // 버튼은 글자 길이만큼, 자리가 모자랄 때만 줄인다 (가운데 빈칸 없이 양 끝으로)
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (picks > 0)
                                    Flexible(
                                      child: _PillButton(
                                        label: l.showPicks(picks),
                                        // 잠긴 묶음은 버튼에 자물쇠: 누르면 무료 묶음을 쓸지 묻는다
                                        icon: src.locked > 0
                                            ? Icons.lock_outline
                                            : null,
                                        filled: true,
                                        onTap: _busy
                                            ? null
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
                                      allSelected ? l.deselectAll : l.selectAll,
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
