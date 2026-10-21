import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../logic/format.dart';
import '../models/day_group.dart';
import '../models/decision.dart';
import '../providers.dart';
import '../theme.dart';
import 'focus_screen.dart';
import 'sort_source.dart';
import 'trash_flow.dart';
import 'widgets.dart';

export 'sort_source.dart' show SortKind;

/// 정리 화면: 앨범처럼 한눈에 보는 그리드.
///
/// 앱이 정리 추천한 사진은 흐리게 + X, 왼쪽 아래에 이유를 붙여 둔다.
/// X를 누르면 정리 ↔ 킵, 사진을 누르면 크게 보기([FocusScreen]).
/// 위쪽 [되돌리기]는 앱이 처음 고른 상태로, [전체 선택]은 모두 X.
/// 묶음, 한 장 사진, 캡처, 똑같은 사진 모두 이 화면을 쓴다.
class SortScreen extends ConsumerStatefulWidget {
  const SortScreen({super.key, required this.kind, this.group, this.place});

  final SortKind kind;

  /// [SortKind.duplicates]가 아니면 필요
  final DayGroup? group;
  final String? place;

  @override
  ConsumerState<SortScreen> createState() => _SortScreenState();
}

class _SortScreenState extends ConsumerState<SortScreen> {
  bool _busy = false;

  Future<void> _toggle(String id, bool marked) => ref
      .read(decisionsProvider.notifier)
      .set([id], marked ? DecisionState.keep : DecisionState.toTrash);

  /// [전체 선택] = 모두 X, [선택 해제] = 모두 킵
  Future<void> _setAll(List<String> ids, DecisionState s) =>
      ref.read(decisionsProvider.notifier).set(ids, s);

  /// [되돌리기]: 여기서 정한 것을 지우고 앱이 처음 고른 상태로
  Future<void> _reset(List<String> changed) async {
    final l = context.l;
    final ok = await _ask(title: l.resetTitle, no: l.cancel, yes: l.reset);
    if (ok != true) return;
    await ref.read(decisionsProvider.notifier).restore({
      for (final id in changed) id: null,
    });
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

  Future<void> _send(List<String> ids, SortSource src) async {
    if (!await _confirmSceneLoss(ids, src) || !mounted) return;
    setState(() => _busy = true);
    await sendToTrash(context, ref, ids);
    if (mounted) setState(() => _busy = false);
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
    final ok = await _ask(
      title: l.sceneLossTitle(emptied.length),
      body: l.sceneLossBody,
      no: l.lookAgain,
      yes: l.toTrash,
    );
    return ok == true;
  }

  Future<bool?> _ask({
    required String title,
    String? body,
    required String no,
    required String yes,
  }) => showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: MehhColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MehhRadius.card),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: body == null
          ? null
          : Text(body, style: const TextStyle(fontSize: 14, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          style: TextButton.styleFrom(foregroundColor: MehhColors.textMuted),
          child: Text(no),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(true),
          style: TextButton.styleFrom(foregroundColor: MehhColors.black),
          child: Text(yes, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final src = watchSortSource(ref, widget.kind, widget.group);
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
    // 사용자가 직접 정한 사진 (되돌리기 대상)
    final changed = [
      for (final id in order)
        if (stateOf(decisions, id) != DecisionState.undecided) id,
    ];
    final allSelected = order.isNotEmpty && marked.length == order.length;
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
                        Row(
                          children: [
                            IconButton(
                              tooltip: l.back,
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(
                                Icons.chevron_left,
                                color: MehhColors.text,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: changed.isEmpty
                                  ? null
                                  : () => _reset(changed),
                              style: TextButton.styleFrom(
                                foregroundColor: MehhColors.text,
                                disabledForegroundColor: MehhColors.icon,
                                minimumSize: const Size(44, 44),
                              ),
                              child: Text(l.reset),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 12, right: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sortTitle(widget.kind, g, widget.place, l),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.kind == SortKind.day && g != null
                                    ? l.countAndRange(
                                        l.photos(order.length),
                                        groupTimeRange(g, l),
                                      )
                                    : l.photos(order.length),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: MehhColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _Summary(
                                analyzing: src.analyzing,
                                marked: marked.length,
                                reason: summaryText(widget.kind, src, l),
                                empty: order.isEmpty,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
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
                              ),
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
                      : () => _send(marked, src),
                  child: Text(
                    marked.isEmpty ? l.noPhotos : l.trashCount(marked.length),
                    style: const TextStyle(
                      fontSize: 15,
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

/// 회색 요약 박스: "[138장] 정리할게요" + 이유 한 줄
class _Summary extends StatelessWidget {
  const _Summary({
    required this.analyzing,
    required this.marked,
    required this.reason,
    required this.empty,
  });

  final bool analyzing;
  final int marked;
  final String? reason;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final Widget title;
    final String detail;
    if (analyzing) {
      title = Text(l.analyzingTitle);
      detail = l.analyzingDetail;
    } else if (empty) {
      title = Text(l.noPhotos);
      detail = '';
    } else if (marked == 0) {
      title = Text(l.noneFound);
      detail = '';
    } else {
      title = Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: MehhColors.black,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  l.photos(marked),
                  style: const TextStyle(
                    color: MehhColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            TextSpan(text: l.willRemoveSuffix),
          ],
        ),
      );
      detail = reason ?? '';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: MehhColors.surface,
        borderRadius: BorderRadius.circular(MehhRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DefaultTextStyle.merge(
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MehhColors.text,
            ),
            child: title,
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(
                fontSize: 13,
                color: MehhColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 홈에서 쓰는 진입 도우미
Route<void> sortRoute(SortKind kind, {DayGroup? group, String? place}) =>
    MaterialPageRoute(
      builder: (_) => SortScreen(kind: kind, group: group, place: place),
    );
