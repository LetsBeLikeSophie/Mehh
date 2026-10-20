import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/format.dart';
import '../models/day_group.dart';
import '../models/decision.dart';
import '../models/photo_meta.dart';
import '../providers.dart';
import '../theme.dart';
import 'focus_screen.dart';
import 'sort_source.dart';
import 'strings.dart';
import 'trash_flow.dart';
import 'widgets.dart';

export 'sort_source.dart' show SortKind;

/// 정리 화면: 앨범처럼 한눈에 보는 그리드.
///
/// 앱이 정리 추천한 사진은 흐리게 + X, 왼쪽 아래에 이유를 붙여 둔다.
/// X를 누르면 정리 ↔ 킵, 사진을 누르면 크게 보기([FocusScreen]).
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

  /// [전체 정리] / [전체 킵]: 모두 그 상태로 시작해서 예외만 X로 바꾼다
  Future<void> _setAll(Iterable<String> ids, DecisionState s) =>
      ref.read(decisionsProvider.notifier).set(ids.toList(), s);

  _StartMode? _modeOf(
    List<PhotoMeta> order,
    Map<String, Decision> decisions,
    List<String> changed,
  ) {
    if (changed.isEmpty) return _StartMode.recommend;
    final states = {for (final p in order) stateOf(decisions, p.id)};
    if (states.length == 1 && states.first == DecisionState.toTrash) {
      return _StartMode.allPile;
    }
    if (states.length == 1 && states.first == DecisionState.keep) {
      return _StartMode.allKeep;
    }
    return null;
  }

  /// [추천]: 이 화면에서 정한 정리·킵·보류를 지우고 앱 추천 상태로 되돌린다.
  /// 이미 휴지통으로 보낸 사진은 앱에서 되돌릴 수 없어서 그대로 둔다.
  Future<void> _reset(List<String> changed) async {
    final ok = await _ask(
      title: '처음 추천대로 되돌릴까요?',
      body:
          '여기서 정한 ${Terms.pile}·${Terms.keep}·${Terms.hold} '
          '${formatCount(changed.length)}장을 앱이 처음 고른 상태로 되돌려요. '
          '휴지통으로 보낸 사진은 그대로예요.',
      no: '취소',
      yes: '되돌리기',
    );
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
    final n = await sendToTrash(context, ref, ids);
    if (!mounted) return;
    setState(() => _busy = false);
    if (n > 0) await _offerKeepRest(src);
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
    final ok = await _ask(
      title: '${formatCount(emptied.length)}개 장면은 사진이 하나도 안 남아요',
      body: '비슷한 사진에 전부 X를 쳤어요. 그래도 ${Terms.toTrash} 보낼까요?',
      no: '다시 볼게요',
      yes: Terms.toTrash,
    );
    return ok == true;
  }

  /// 휴지통으로 보낸 뒤 아직 고르지 않은 사진이 남아 있으면, 한 번에 킵할지 묻는다.
  /// "앱이 먼저 다 해놓고 사용자는 확인만": 추천을 보냈으면 나머지는 남기는 것으로 끝낸다.
  Future<void> _offerKeepRest(SortSource src) async {
    final decisions = ref.read(decisionsProvider).value ?? const {};
    final rest = [
      for (final p in src.photos)
        if (stateOf(decisions, p.id) == DecisionState.undecided) p.id,
    ];
    if (rest.isEmpty || !mounted) return;
    final ok = await _ask(
      title: '나머지 ${formatCount(rest.length)}장은 ${Terms.keep}할까요?',
      body: widget.kind == SortKind.day
          ? '${Terms.keep}하면 이 묶음은 다 본 걸로 할게요.'
          : '${Terms.keep}하면 여기 정리가 끝나요.',
      no: '더 볼게요',
      yes: '${formatCount(rest.length)}장 ${Terms.keep}',
    );
    if (ok != true) return;
    await ref.read(decisionsProvider.notifier).set(rest, DecisionState.keep);
  }

  Future<bool?> _ask({
    required String title,
    required String body,
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
      content: Text(body, style: const TextStyle(fontSize: 14, height: 1.5)),
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
    final src = watchSortSource(ref, widget.kind, widget.group);
    final decisions = ref.watch(decisionsProvider).value ?? const {};
    final entities = ref.read(photoLibraryProvider).entities;
    final order = [
      for (final p in src.photos)
        if (stateOf(decisions, p.id) != DecisionState.trashed) p,
    ];
    final marked = [
      for (final p in order)
        if (isMarked(p.id, decisions, src)) p.id,
    ];
    final undecided = order
        .where(
          (p) =>
              stateOf(decisions, p.id) == DecisionState.undecided &&
              !marked.contains(p.id),
        )
        .length;
    // 사용자가 직접 정한 사진 (휴지통으로 간 것은 되돌릴 수 없어서 빼고)
    final changed = [
      for (final p in order)
        if (stateOf(decisions, p.id) != DecisionState.undecided) p.id,
    ];
    final g = widget.group;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 20, 12),
                    sliver: SliverList.list(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: '돌아가기',
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(
                                Icons.chevron_left,
                                color: MehhColors.text,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sortTitle(widget.kind, g, widget.place),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.kind == SortKind.day && g != null
                                    ? '${formatCount(order.length)}장 · ${groupTimeRange(g)}'
                                    : '${formatCount(order.length)}장',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: MehhColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _StartChips(
                                mode: _modeOf(order, decisions, changed),
                                onRecommend: changed.isEmpty
                                    ? null
                                    : () => _reset(changed),
                                onAllPile: () => _setAll(
                                  order.map((p) => p.id),
                                  DecisionState.toTrash,
                                ),
                                onAllKeep: () => _setAll(
                                  order.map((p) => p.id),
                                  DecisionState.keep,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _Summary(
                                analyzing: src.analyzing,
                                marked: marked.length,
                                reason: src.summary,
                                empty: order.isEmpty,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                      itemCount: order.length,
                      itemBuilder: (_, i) {
                        final id = order[i].id;
                        final out = marked.contains(id);
                        final state = stateOf(decisions, id);
                        final tag = src.tags[id];
                        return GestureDetector(
                          onTap: () => _open(id),
                          child: Semantics(
                            button: true,
                            label: out ? '정리할 사진' : '사진',
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
                                  child: XToggle(
                                    on: out,
                                    onTap: () => _toggle(id, out),
                                  ),
                                ),
                                if (state == DecisionState.hold)
                                  const Positioned(
                                    left: 4,
                                    bottom: 4,
                                    child: MehhBadge(
                                      Terms.hold,
                                      inverted: true,
                                    ),
                                  )
                                else if (tag != null)
                                  Positioned(
                                    left: 4,
                                    bottom: 4,
                                    child: MehhBadge(tag, inverted: out),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: marked.isNotEmpty
                    ? FilledButton(
                        onPressed: _busy ? null : () => _send(marked, src),
                        child: Text(
                          '${formatCount(marked.length)}장 ${Terms.toTrash}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : OutlinedButton(
                        onPressed: undecided == 0
                            ? null
                            : () => _offerKeepRest(src),
                        child: Text(
                          undecided == 0
                              ? '다 골랐어요'
                              : '남은 ${formatCount(undecided)}장 다 ${Terms.keep}',
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

enum _StartMode { recommend, allPile, allKeep }

/// 시작 상태 칩: [추천] [전체 정리] [전체 킵]. 지금 상태와 같은 칩이 검게 보인다.
class _StartChips extends StatelessWidget {
  const _StartChips({
    required this.mode,
    required this.onRecommend,
    required this.onAllPile,
    required this.onAllKeep,
  });

  final _StartMode? mode;

  /// 이미 추천 상태면 null
  final VoidCallback? onRecommend;
  final VoidCallback onAllPile;
  final VoidCallback onAllKeep;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        _chip('추천', mode == _StartMode.recommend, onRecommend),
        _chip('전체 ${Terms.pile}', mode == _StartMode.allPile, onAllPile),
        _chip('전체 ${Terms.keep}', mode == _StartMode.allKeep, onAllKeep),
      ],
    );
  }

  Widget _chip(String text, bool on, VoidCallback? onTap) => Semantics(
    button: true,
    selected: on,
    child: GestureDetector(
      onTap: on ? null : onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? MehhColors.black : MehhColors.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
            color: on ? MehhColors.white : MehhColors.text,
          ),
        ),
      ),
    ),
  );
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
    final Widget title;
    final String detail;
    if (analyzing) {
      title = const Text('사진을 살펴보는 중이에요');
      detail = '추천이 조금씩 채워져요.';
    } else if (empty) {
      title = const Text('정리할 사진이 없어요');
      detail = '';
    } else if (marked == 0) {
      title = const Text('정리할 사진을 못 찾았어요');
      detail = 'X를 눌러 직접 고르거나, 사진을 눌러 크게 보세요.';
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
                  '${formatCount(marked)}장',
                  style: const TextStyle(
                    color: MehhColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const TextSpan(text: ' 정리할게요'),
          ],
        ),
      );
      detail = [?reason, 'X를 눌러 바꾸고, 사진을 누르면 크게 봐요.'].join('\n');
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
