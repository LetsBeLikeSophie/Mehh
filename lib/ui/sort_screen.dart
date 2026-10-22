import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/handoff.dart';
import '../data/pro.dart';
import '../l10n/l10n.dart';
import '../logic/format.dart';
import '../logic/pick_stats.dart';
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

  /// Cortex로 보낸 캡처. Cortex가 다 읽은 뒤(Mehh로 돌아왔을 때) 휴지통으로 옮긴다.
  List<String>? _sentToCortex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ids = _sentToCortex;
    if (state != AppLifecycleState.resumed || ids == null || !mounted) return;
    _sentToCortex = null;
    _trashAfterCortex(ids);
  }

  /// 여러 장을 한 번에 Cortex로 보낸다. 분석은 Cortex가 하고, 보낸 캡처는 휴지통으로.
  Future<void> _sendCortex(List<String> ids) async {
    setState(() => _busy = true);
    final r = await ref.read(handoffProvider).sendManyToCortex(ids);
    if (!mounted) return;
    final l = context.l;
    switch (r) {
      case SendResult.ok:
        _sentToCortex = ids; // 돌아오면 휴지통으로
      case SendResult.unsupported:
        setState(() => _busy = false);
        showNote(context, l.cortexMultiUnsupported);
      case SendResult.failed:
        setState(() => _busy = false);
        showNote(context, l.cortexFailed);
    }
  }

  Future<void> _trashAfterCortex(List<String> ids) async {
    await sendToTrash(
      context,
      ref,
      ids,
      doneNote: (n) => context.l.cortexSentTrashed(n),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggle(String id, bool marked) => ref
      .read(decisionsProvider.notifier)
      .set([id], marked ? DecisionState.keep : DecisionState.toTrash);

  /// [전체 선택] = 모두 X, [선택 해제] = 모두 킵
  Future<void> _setAll(List<String> ids, DecisionState s) =>
      ref.read(decisionsProvider.notifier).set(ids, s);

  /// [추천 보기]: 앱이 고른 사진에 X를 친다. 그날의 묶음은 이번 달 무료 묶음이나 Pro로 열고,
  /// 다 썼으면 Pro 안내. 다시 누르면 추천대로 다시 X.
  Future<void> _showPicks(SortSource src) async {
    final g = widget.group;
    final pro = ref.read(proProvider.notifier);
    if (widget.kind == SortKind.day && src.locked > 0 && g != null) {
      if (!await pro.unlock(g.id, photoIds: g.photos.map((p) => p.id))) {
        if (!mounted) return;
        await showProSheet(context);
        // 시트에서 Pro를 샀으면 다시 누르지 않아도 이어서 추천을 X로 (UX 리뷰 2026-10-22).
        // 결제 대기·취소면 그대로 끝
        if (!(ref.read(proProvider).value?.pro ?? false)) return;
      } else {
        final s = await ref.read(proProvider.future);
        if (!s.pro && mounted) {
          showNote(context, context.l.freeLeftNote(s.freeLeft(DateTime.now())));
        }
      }
    }
    final ids = widget.kind == SortKind.duplicates || g == null
        ? src.suggested
        : ref.read(groupPlanProvider(g)).trash.keys.toSet();
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
    if (mounted) setState(() => _busy = false);
    if (n > 0 && nudge && await pro.takeNudge() && mounted) {
      await showProSheet(context, lead: context.l.proNudge(n));
    }
  }

  /// 추천 정확도 기록 (SPEC 6-8). [추천 보기]를 누른 경우만 센다 (캡처는 추천이 없다).
  Future<void> _recordPicks(
    List<String> sent,
    SortSource src,
    List<String> shown,
  ) async {
    if (widget.kind == SortKind.screenshots || _picked.isEmpty) return;
    await ref
        .read(storeProvider)
        .addPicks(
          pickRecords(
            at: DateTime.now(),
            kind: widget.kind.name,
            shown: shown,
            sent: sent.toSet(),
            suggested: {..._picked, ...src.suggested},
            tags: {
              ..._seenTags,
              for (final e in src.tags.entries) e.key: e.value.name,
            },
          ),
        );
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
    final freeLeft =
        ref.watch(proProvider).value?.freeLeft(DateTime.now()) ?? 0;
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
      final tag = src.tags[id];
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
    final count = l.photos(order.length);
    final countLine = widget.kind == SortKind.day && g != null
        ? l.countAndRange(count, groupTimeRange(g, l))
        : count;

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
                              Text(
                                sortTitle(widget.kind, g, widget.place, l),
                                style: const TextStyle(
                                  fontSize: MehhText.title,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                src.analyzing
                                    ? l.countAndRange(
                                        countLine,
                                        l.analyzingShort,
                                      )
                                    : countLine,
                                style: const TextStyle(
                                  fontSize: MehhText.bodySmall,
                                  color: MehhColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (picks > 0)
                                    Flexible(
                                      child: _PillButton(
                                        label: l.showPicks(picks),
                                        filled: true,
                                        onTap: _busy
                                            ? null
                                            : () => _showPicks(src),
                                      ),
                                    ),
                                  if (cortex)
                                    Flexible(
                                      child: _PillButton(
                                        label: marked.isEmpty
                                            ? l.cortexSend
                                            : l.cortexSendCount(marked.length),
                                        icon: Icons.north_east,
                                        onTap: _busy || marked.isEmpty
                                            ? null
                                            : () => _sendCortex(marked),
                                      ),
                                    ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: order.isEmpty
                                        ? null
                                        : () => _setAll(
                                            order,
                                            allSelected
                                                ? DecisionState.keep
                                                : DecisionState.toTrash,
                                          ),
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
                              // 무료 묶음을 쓰는 버튼은 누르기 전에 무엇이 쓰이는지 보여 준다
                              if (src.locked > 0)
                                Text(
                                  freeLeft > 0
                                      ? l.picksCostNote(freeLeft)
                                      : l.picksNoFreeNote(
                                          formatDate(
                                            nextFreeReset(DateTime.now()),
                                            l.localeName,
                                          ),
                                          freeGroupsPerMonth,
                                        ),
                                  style: const TextStyle(
                                    fontSize: MehhText.caption,
                                    color: MehhColors.textMuted,
                                  ),
                                ),
                              if (cortex && marked.isNotEmpty)
                                Text(
                                  l.cortexThenTrash,
                                  style: const TextStyle(
                                    fontSize: MehhText.caption,
                                    color: MehhColors.textMuted,
                                  ),
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
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy || marked.isEmpty
                      ? null
                      : () => _send(marked, src, order),
                  child: Text(
                    marked.isEmpty ? l.noPhotos : l.trashCount(marked.length),
                    style: const TextStyle(
                      fontSize: MehhText.body,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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
    final text = Text(label, overflow: TextOverflow.ellipsis);
    final iconWidget = icon == null ? null : Icon(icon, size: 16);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: filled
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
            ),
    );
  }
}

/// 홈에서 쓰는 진입 도우미
Route<void> sortRoute(SortKind kind, {DayGroup? group, String? place}) =>
    MaterialPageRoute(
      builder: (_) => SortScreen(kind: kind, group: group, place: place),
    );
