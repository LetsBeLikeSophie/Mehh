import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/format.dart';
import '../logic/recommend.dart';
import '../models/day_group.dart';
import '../models/decision.dart';
import '../providers.dart';
import '../theme.dart';
import 'photo_viewer.dart';
import 'swipe_screen.dart';
import 'widgets.dart';

/// 묶음 안: 앱이 고른 정리 추천을 보여주고, 사용자는 예외만 탭으로 고친다.
class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key, required this.group, this.place});

  final DayGroup group;
  final String? place;

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  /// 추천됐지만 살리기로 한 사진
  final _rescued = <String>{};

  /// 추천은 아니지만 정리하기로 한 사진
  final _added = <String>{};
  bool _busy = false;

  DayGroup get g => widget.group;

  Set<String> _toTrash(GroupPlan plan) => {
    ...plan.trash.keys.where((id) => !_rescued.contains(id)),
    ..._added,
  };

  void _toggle(String id, GroupPlan plan) {
    setState(() {
      if (plan.trash.containsKey(id)) {
        _rescued.contains(id) ? _rescued.remove(id) : _rescued.add(id);
      } else {
        _added.contains(id) ? _added.remove(id) : _added.add(id);
      }
    });
  }

  /// 나머지 사진은 남기기로 기록해서 이 날은 정리 끝
  Future<void> _keepRest(Set<String> except) async {
    final decisions = ref.read(decisionsProvider).value ?? const {};
    final rest = [
      for (final p in g.photos)
        if (!except.contains(p.id) &&
            stateOf(decisions, p.id) == DecisionState.undecided)
          p.id,
    ];
    await ref.read(decisionsProvider.notifier).set(rest, DecisionState.keep);
  }

  Future<void> _apply(GroupPlan plan) async {
    final ids = _toTrash(plan);
    setState(() => _busy = true);
    var n = 0;
    if (ids.isNotEmpty) {
      n = await ref.read(cleanerProvider).trash(ids);
      if (n == 0) {
        // 시스템 확인 창에서 취소
        if (mounted) setState(() => _busy = false);
        return;
      }
    }
    await _keepRest(ids);
    if (!mounted) return;
    showNote(context, n > 0 ? '${formatCount(n)}장을 휴지통으로 보냈어요' : '이 날은 정리 끝');
    Navigator.of(context).pop();
  }

  Future<void> _keepAll() async {
    await _keepRest(const {});
    if (!mounted) return;
    showNote(context, '이 날은 다 남겼어요');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final entities = ref.read(photoLibraryProvider).entities;
    final plan = ref.watch(groupPlanProvider(g));
    final decisions = ref.watch(decisionsProvider).value ?? const {};
    final toTrash = _toTrash(plan);
    final analyzing = plan.analyzed < g.count;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                    sliver: SliverList.list(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: '묶음 목록으로',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.chevron_left,
                              color: MehhColors.text,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                groupTitle(g, place: widget.place),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${formatCount(g.count)}장 · ${groupTimeRange(g)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: MehhColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _Summary(
                                plan: plan,
                                count: toTrash.length,
                                analyzing: analyzing,
                                total: g.count,
                              ),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      '눌러서 살릴 사진만 고르세요',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: MehhColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _busy ? null : _keepAll,
                                    style: TextButton.styleFrom(
                                      foregroundColor: MehhColors.text,
                                      minimumSize: const Size(44, 44),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Text(
                                      '이 날은 다 남기기',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
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
                      itemCount: g.photos.length,
                      itemBuilder: (_, i) {
                        final p = g.photos[i];
                        final out = toTrash.contains(p.id);
                        final state = stateOf(decisions, p.id);
                        return GestureDetector(
                          onTap: () => _toggle(p.id, plan),
                          onLongPress: () => openPhoto(context, p.id),
                          child: Semantics(
                            button: true,
                            label: out ? '정리할 사진' : '남길 사진',
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Opacity(
                                  opacity: out ? 0.45 : 1,
                                  child: PhotoThumb(entity: entities[p.id]),
                                ),
                                if (out)
                                  const Positioned(
                                    right: 4,
                                    top: 4,
                                    child: XMark(),
                                  ),
                                if (plan.best.contains(p.id))
                                  const Positioned(
                                    left: 4,
                                    bottom: 4,
                                    child: MehhBadge('베스트'),
                                  )
                                else if (state == DecisionState.hold)
                                  const Positioned(
                                    left: 4,
                                    bottom: 4,
                                    child: MehhBadge('보류', inverted: true),
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
              child: Row(
                children: [
                  Expanded(
                    flex: 10,
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SwipeScreen(group: g),
                              ),
                            ),
                      child: const Text(
                        '하나씩 보기',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 14,
                    child: FilledButton(
                      onPressed: _busy || analyzing ? null : () => _apply(plan),
                      child: Text(
                        toTrash.isEmpty
                            ? '이대로 끝내기'
                            : '${formatCount(toTrash.length)}장 정리',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
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
    required this.plan,
    required this.count,
    required this.analyzing,
    required this.total,
  });

  final GroupPlan plan;
  final int count;
  final bool analyzing;
  final int total;

  @override
  Widget build(BuildContext context) {
    final Widget title;
    final String detail;
    if (analyzing) {
      title = const Text('사진을 살펴보는 중이에요');
      detail = '${formatCount(plan.analyzed)} / ${formatCount(total)}장';
    } else if (count == 0) {
      title = const Text('정리할 사진을 못 찾았어요');
      detail = '비슷한 연속 컷이나 흔들린 사진이 없어요.';
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
                  '${formatCount(count)}장',
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
      detail = '${trashSummary(plan)}\n잘못 골라도 휴지통에서 30일 안에 되살릴 수 있어요.';
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
