import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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

part 'sort_screen_cortex.dart';
part 'sort_screen_paint.dart';
part 'sort_screen_trash.dart';

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

  /// 손으로(X 버튼·끌어서·[전체 선택]) 고른 사진. Cortex로 보낼 수 있는 것 (C1)
  final _chosen = <String>{};

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

  /// 파트 파일(sort_screen_*.dart)의 확장에서 화면을 다시 그릴 때
  void _set(VoidCallback f) => setState(f);

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

  Future<void> _toggle(String id, bool marked) {
    // 손으로 누른 사진은 추천이 아니라 "직접 고른 사진" (Cortex로 보낼 수 있다, C1)
    marked ? _chosen.remove(id) : _chosen.add(id);
    return ref.read(decisionsProvider.notifier).set([
      id,
    ], marked ? DecisionState.keep : DecisionState.toTrash);
  }

  /// 지금 사진첩의 같은 묶음 (열어 둔 사이 새로 찍은 사진까지, UX-70)
  DayGroup? get _group => freshGroup(
    ref.read(libraryProvider).value?.groups ?? const [],
    widget.group,
  );

  /// [추천 보기]를 켠 적이 있나: 이 화면에서 켰거나(_picked), 손으로 고르지 않았는데 X인 추천이
  /// 있으면(화면을 나갔다 와도 DB에 X로 남아 있다). 처음부터 X인 것은 신호가 아니다.
  /// [추천 보기] 켜짐 표시와 정확도 기록이 같이 쓴다 (UX-60 2026-10-27)
  bool _picksTurnedOn(SortSource src, Set<String> marked) =>
      src.suggested.any(_picked.contains) ||
      src.suggested.any(
        (id) =>
            !src.preMarked.contains(id) &&
            marked.contains(id) &&
            !_chosen.contains(id),
      );

  /// [전체 선택] = 모두 X
  Future<void> _selectAll(List<String> ids) {
    _chosen.addAll(ids); // 직접 고른 것
    return ref.read(decisionsProvider.notifier).set(ids, DecisionState.toTrash);
  }

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

  /// 가장자리에서 시작한 끌기: 사진 선택 대신 뒤로 가기 (2026-10-24 Sophie: 캡처 묶음에서 스와이프로
  /// 뒤로 안 갔다 — 사진이 화면을 꽉 채워 끌어 선택이 먼저 잡혔다)
  Offset? _edgeFrom;
  double _edgeDx = 0;

  String? _paintLast;

  Future<void> _rename(DayGroup g) async {
    final original = sortTitle(widget.kind, g, widget.place, context.l);
    final v = await askGroupName(
      context,
      current:
          groupNameOf(
            ref.read(groupNamesProvider).value,
            g,
            all: ref.read(libraryProvider).value?.groups ?? const [],
          ) ??
          original,
      original: original,
    );
    if (v != null) {
      await ref.read(groupNamesProvider.notifier).rename(g, v);
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
    final g = _group;
    final pro = ref.read(proProvider.notifier);
    // 그날의 묶음은 열려 있어도 늘 unlock을 부른다: Pro면 사진만 기억해서
    // 1년 이용권이 끝나도 계속 열려 있게 한다 (F3-A, UX 리뷰 2026-10-23 UX-35)
    final proNow = (await ref.read(proProvider.future)).pro;
    // 비공개 테스트 동안 본 묶음은 기억해 둔다: 테스트가 끝나도 계속 열려 있게 (T1-A)
    if (widget.kind == SortKind.day &&
        g != null &&
        ref.read(closedTestFreeProvider)) {
      await pro.keepOpen([for (final p in g.photos) p.id]);
    }
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
          group: _group,
          place: widget.place,
          initialId: id,
          picksShown: _picked.isNotEmpty,
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

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final group = freshGroup(
      ref.watch(libraryProvider).value?.groups ?? const [],
      widget.group,
    );
    final src = watchSortSource(ref, widget.kind, group);
    for (final e in src.tags.entries) {
      _seenTags[e.key] = e.value.name;
    }
    _preMarkedSeen.addAll(src.preMarked);
    // Cortex로 보내기는 모든 종류에서 같은 자리 (2026-10-24 Sophie).
    // 큰 동영상은 빼다: Cortex는 사진·캡처만 받는다 (SPEC 큰 동영상 "Cortex 없음")
    final cortexKind = widget.kind != SortKind.videos;
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
    final cortexIds = _cortexIds(marked, src, decisions);
    final picksOn =
        src.locked == 0 &&
        src.suggested.every(markedSet.contains) &&
        _picksTurnedOn(src, markedSet);
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
      final tag = shownTag(
        src,
        id,
        marked: out,
        picksShown: _picked.isNotEmpty,
      );
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

    final g = group;
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
                                                  groupNameOf(
                                                    ref
                                                        .watch(
                                                          groupNamesProvider,
                                                        )
                                                        .value,
                                                    g,
                                                    all:
                                                        ref
                                                            .watch(
                                                              libraryProvider,
                                                            )
                                                            .value
                                                            ?.groups ??
                                                        const [],
                                                  ) ??
                                                  sortTitle(
                                                    widget.kind,
                                                    g,
                                                    widget.place,
                                                    l,
                                                  ),
                                            ),
                                            TextSpan(
                                              text:
                                                  '  ${widget.kind == SortKind.videos ? l.videosCount(order.length) : l.photos(order.length)}',
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
                            ? (widget.kind == SortKind.videos
                                  ? l.nothingMarkedVideos
                                  : l.nothingMarked)
                            : _trashCount(l, marked.length),
                        style: const TextStyle(
                          fontSize: MehhText.body,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  // 고른 캡처가 있으면 [휴지통으로] 옆에 작은 Cortex 버튼 (공유하기처럼, 2026-10-23 Sophie)
                  // Cortex가 없어도 버튼은 보이고, 누르면 받으러 가기 (2026-10-25 Sophie)
                  if (cortexKind &&
                      (cortex || cortexStoreUrl.isNotEmpty) &&
                      cortexIds.any((id) => cortexSent[id] != true)) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : cortex
                          ? () => _sendCortex(cortexIds)
                          : _getCortex,
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
