import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../logic/duplicates.dart';
import '../logic/format.dart';
import '../logic/recommend.dart';
import '../models/day_group.dart';
import '../models/decision.dart';
import '../models/photo_meta.dart';
import '../providers.dart';
import '../theme.dart';
import 'photo_viewer.dart';
import 'trash_flow.dart';
import 'widgets.dart';

/// 정리 화면에 들어가는 것: 그날의 묶음, 한 장 사진, 캡처, 똑같은 사진
enum SortKind { day, singles, screenshots, duplicates }

/// 모든 정리를 같은 화면, 같은 조작으로 한다.
///
/// 밀기: 위 = 보류, 아래 = 킵, 왼쪽 = 정리, 오른쪽 = 이전 사진.
/// 남은·보류·킵·정리 줄의 사진을 누르면 그 사진이 가운데로 와서 다시 고를 수 있다.
/// 앱이 추천한 사진은 정리 줄에 미리 넣어 두고, 사용자는 확인만 한다.
/// 정리 줄은 [휴지통으로]를 누를 때만 휴대폰 휴지통으로 간다.
class SortScreen extends ConsumerStatefulWidget {
  const SortScreen({super.key, required this.kind, this.group, this.place});

  final SortKind kind;

  /// [SortKind.duplicates]가 아니면 필요
  final DayGroup? group;
  final String? place;

  @override
  ConsumerState<SortScreen> createState() => _SortScreenState();
}

/// 화면에 보여줄 사진과 앱 추천
class _Source {
  const _Source({
    required this.photos,
    this.suggested = const {},
    this.notes = const {},
    this.summary,
    this.analyzing = false,
    this.units = const [],
  });

  /// 연속 컷·중복 묶음 (2장 이상). 정리 줄을 보낼 때 하나도 안 남는 묶음이 있으면 묻는다.
  final List<List<String>> units;

  /// 보여줄 순서
  final List<PhotoMeta> photos;

  /// 정리 줄에 미리 넣어 둘 사진 (앱 추천)
  final Set<String> suggested;

  /// 사진 위에 붙일 한 줄 ("베스트 · 초점 선명", "똑같은 사진")
  final Map<String, String> notes;
  final String? summary;
  final bool analyzing;
}

class _Undo {
  const _Undo(this.before, this.id);
  final Map<String, Decision?> before;
  final String id;
}

/// 사진이 들어오고 나가는 방향
enum _Motion { next, prev, keep, hold, trash }

class _SortScreenState extends ConsumerState<SortScreen> {
  String? _currentId;
  bool _started = false;

  Offset _drag = Offset.zero;
  Offset _raw = Offset.zero;
  Axis? _axis;
  bool _dragging = false;
  bool _zooming = false;
  double _zoom = 1;

  _Motion _motion = _Motion.next;
  final _undo = <_Undo>[];

  /// 이번에 들어와서 고른 결정 (나갈 때 안내용)
  final _session = <String, DecisionState>{};
  bool _busy = false;

  // ───────────────────────── 보여줄 사진

  _Source _source() {
    final features = ref.watch(analysisProvider.select((s) => s.features));
    final g = widget.group;
    switch (widget.kind) {
      case SortKind.duplicates:
        final sets = ref.watch(duplicatesProvider).value;
        if (sets == null) return const _Source(photos: [], analyzing: true);
        final decisions = ref.watch(decisionsProvider).value ?? const {};
        bool gone(String id) {
          final s = stateOf(decisions, id);
          return s == DecisionState.toTrash || s == DecisionState.trashed;
        }

        // 묶음마다 하나는 남긴다: 원본을 정리하면 다음 사진이 남길 사진이 된다
        final keepers = {for (final s in sets) ?keeperOf(s, gone)};
        return _Source(
          photos: [
            for (final s in sets) ...[s.keep, ...s.remove],
          ],
          suggested: {
            for (final s in sets)
              for (final p in [s.keep, ...s.remove])
                if (!keepers.contains(p.id)) p.id,
          },
          notes: {
            for (final s in sets)
              for (final p in [s.keep, ...s.remove])
                p.id: keepers.contains(p.id) ? '남길 사진' : '똑같은 사진',
          },
          summary: '똑같은 사진은 정리 줄에 넣어 뒀어요',
          units: [
            for (final s in sets) [s.keep.id, ...s.remove.map((p) => p.id)],
          ],
        );
      case SortKind.screenshots:
        return _Source(photos: g!.photos.reversed.toList());
      case SortKind.day:
      case SortKind.singles:
        final plan = ref.watch(groupPlanProvider(g!));
        final notes = <String, String>{};
        for (final b in plan.bursts) {
          for (final p in b) {
            if (plan.best.contains(p.id)) {
              final r = bestReason(features[p.id], [
                for (final q in b) features[q.id],
              ]);
              notes[p.id] = r.isEmpty ? '베스트' : '베스트 · $r';
            }
          }
        }
        plan.trash.forEach((id, reason) {
          notes[id] = switch (reason) {
            TrashReason.burst => '비슷한 연속 컷',
            TrashReason.blurry => '더 선명한 컷이 있어요',
            TrashReason.junk => '실수로 찍힌 것 같아요',
          };
        });
        final summary = trashSummary(plan);
        return _Source(
          photos: widget.kind == SortKind.singles
              ? g.photos.reversed.toList()
              : g.photos,
          suggested: plan.trash.keys.toSet(),
          notes: notes,
          summary: summary.isEmpty ? null : '정리 줄에 미리 넣어 뒀어요 · $summary',
          analyzing: plan.analyzed < g.count,
          units: [
            for (final b in plan.bursts)
              if (b.length > 1) [for (final p in b) p.id],
          ],
        );
    }
  }

  String get _title => switch (widget.kind) {
    SortKind.duplicates => '똑같은 사진',
    _ => groupTitle(widget.group!, place: widget.place),
  };

  // ───────────────────────── 결정

  Future<void> _decide(
    String id,
    DecisionState s,
    List<PhotoMeta> order,
    bool Function(String) isLeft,
  ) async {
    final before = await ref.read(decisionsProvider.notifier).set([id], s);
    _undo.add(_Undo(before, id));
    _session[id] = s;
    if (!mounted) return;
    // 다음 남은 사진으로 (현재 위치 뒤에서 먼저 찾고, 없으면 처음부터)
    final i = order.indexWhere((p) => p.id == id);
    String? next;
    for (var k = 1; k <= order.length; k++) {
      final p = order[(i + k) % order.length];
      if (p.id != id && isLeft(p.id)) {
        next = p.id;
        break;
      }
    }
    setState(() {
      _motion = switch (s) {
        DecisionState.hold => _Motion.hold,
        DecisionState.keep => _Motion.keep,
        _ => _Motion.trash,
      };
      _currentId = next;
    });
  }

  void _goTo(String? id, {_Motion motion = _Motion.next}) {
    if (id == null || id == _currentId) return;
    setState(() {
      _motion = motion;
      _currentId = id;
    });
  }

  Future<void> _undoLast() async {
    if (_undo.isEmpty) return;
    final u = _undo.removeLast();
    _session.remove(u.id);
    await ref.read(decisionsProvider.notifier).restore(u.before);
    if (!mounted) return;
    _goTo(u.id, motion: _Motion.prev);
  }

  Future<void> _sendTrash(List<String> ids, _Source src) async {
    // 연속 컷·중복 묶음이 통째로 사라지면 한 번 묻는다
    final decisions = ref.read(decisionsProvider).value ?? const {};
    final sending = ids.toSet();
    final emptied = src.units.where(
      (u) => u.every(
        (id) =>
            sending.contains(id) ||
            stateOf(decisions, id) == DecisionState.trashed,
      ),
    );
    if (emptied.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: MehhColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MehhRadius.card),
          ),
          title: Text(
            '${formatCount(emptied.length)}개 장면은 사진이 하나도 안 남아요',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            '비슷한 사진을 전부 정리 줄에 넣었어요. 그래도 휴지통으로 보낼까요?',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: MehhColors.textMuted,
              ),
              child: const Text('다시 볼게요'),
            ),
            TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              style: TextButton.styleFrom(foregroundColor: MehhColors.black),
              child: const Text(
                '휴지통으로',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    final n = await sendToTrash(context, ref, ids);
    if (!mounted) return;
    setState(() {
      _busy = false;
      // 휴지통으로 간 사진은 앱에서 되돌릴 수 없다 (갤러리 휴지통에서 되살린다)
      if (n > 0) _undo.removeWhere((u) => sending.contains(u.id));
    });
  }

  /// 나갈 때 이번에 고른 것만 알려 준다. 결정은 고를 때마다 이미 저장돼 있다.
  void _noteOnLeave(int pile) {
    final keep = _session.values.where((s) => s == DecisionState.keep).length;
    final hold = _session.values.where((s) => s == DecisionState.hold).length;
    if (keep + hold == 0 && pile == 0) return;
    final parts = [if (keep > 0) '킵 $keep', if (hold > 0) '보류 $hold'];
    final saved = parts.isEmpty ? '' : '${parts.join(' · ')} 저장했어요';
    final rest = pile > 0 ? '정리 줄 $pile장은 그대로 있어요' : '';
    showNote(context, [saved, rest].where((t) => t.isNotEmpty).join(' · '));
  }

  // ───────────────────────── 밀기·확대

  void _onScaleStart(ScaleStartDetails d) => setState(() {
    _dragging = true;
    _zooming = d.pointerCount >= 2;
  });

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_zooming || d.pointerCount >= 2) {
      // 두 손가락: 확대해서 보기 (손을 떼면 원래 크기로)
      setState(() {
        _zooming = true;
        _drag = Offset.zero;
        _zoom = d.scale.clamp(1.0, 4.0);
      });
      return;
    }
    _raw += d.focalPointDelta;
    // 처음 움직인 방향(가로/세로) 한 축으로만 움직인다
    _axis ??= _raw.distance < 12
        ? null
        : (_raw.dx.abs() > _raw.dy.abs() ? Axis.horizontal : Axis.vertical);
    setState(() {
      _drag = switch (_axis) {
        Axis.horizontal => Offset(_raw.dx, 0),
        Axis.vertical => Offset(0, _raw.dy),
        null => Offset.zero,
      };
    });
  }

  /// 손을 뗐을 때 어떤 동작인지. null이면 제자리로.
  String? _onScaleEnd() {
    final d = _drag;
    final wasZoom = _zooming;
    setState(() {
      _drag = Offset.zero;
      _raw = Offset.zero;
      _axis = null;
      _dragging = false;
      _zooming = false;
      _zoom = 1;
    });
    if (wasZoom) return null;
    if (d.dy < -90) return 'hold';
    if (d.dy > 90) return 'keep';
    if (d.dx < -80) return 'trash';
    if (d.dx > 80) return 'prev';
    return null;
  }

  String? get _dragLabel {
    if (_drag.dy < -40) return '보류';
    if (_drag.dy > 40) return '킵';
    if (_drag.dx < -40) return '정리';
    if (_drag.dx > 40) return '이전 사진';
    return null;
  }

  (Offset, Offset) get _slide => switch (_motion) {
    _Motion.next => (const Offset(1, 0), const Offset(-1, 0)),
    _Motion.prev => (const Offset(-1, 0), const Offset(1, 0)),
    _Motion.keep => (const Offset(0, -0.15), const Offset(0, 1.1)),
    _Motion.hold => (const Offset(0, 0.15), const Offset(0, -1.1)),
    _Motion.trash => (const Offset(1, 0), const Offset(-1.1, 0)),
  };

  // ───────────────────────── 화면

  @override
  Widget build(BuildContext context) {
    final src = _source();
    final decisions = ref.watch(decisionsProvider).value ?? const {};
    final entities = ref.read(photoLibraryProvider).entities;

    DecisionState stateOfId(String id) => stateOf(decisions, id);
    final order = [
      for (final p in src.photos)
        if (stateOfId(p.id) != DecisionState.trashed) p,
    ];
    bool inPile(String id) {
      final s = stateOfId(id);
      return s == DecisionState.toTrash ||
          (s == DecisionState.undecided && src.suggested.contains(id));
    }

    bool isLeft(String id) =>
        stateOfId(id) == DecisionState.undecided && !src.suggested.contains(id);

    List<String> byRecent(DecisionState s) {
      final list = [
        for (final p in order)
          if (decisions[p.id] case final d? when d.state == s) d,
      ]..sort((a, b) => b.at.compareTo(a.at));
      return [for (final d in list) d.photoId];
    }

    final left = [
      for (final p in order)
        if (isLeft(p.id)) p.id,
    ];
    final holds = byRecent(DecisionState.hold);
    final keeps = byRecent(DecisionState.keep);
    final pile = [
      ...byRecent(DecisionState.toTrash),
      for (final p in order)
        if (stateOfId(p.id) == DecisionState.undecided &&
            src.suggested.contains(p.id))
          p.id,
    ];

    // 처음 들어오면 남은 사진의 첫 장부터
    if (!_started && order.isNotEmpty) {
      _started = true;
      _currentId = left.isNotEmpty ? left.first : null;
    }
    final ids = {for (final p in order) p.id};
    final current = ids.contains(_currentId) ? _currentId : null;

    Future<void> act(String? what) async {
      final id = current;
      if (what == null || id == null) return;
      switch (what) {
        case 'hold':
          await _decide(id, DecisionState.hold, order, isLeft);
        case 'keep':
          await _decide(id, DecisionState.keep, order, isLeft);
        case 'trash':
          await _decide(id, DecisionState.toTrash, order, isLeft);
        case 'prev':
          final i = order.indexWhere((p) => p.id == id);
          if (i > 0) _goTo(order[i - 1].id, motion: _Motion.prev);
      }
    }

    final (inFrom, outTo) = _slide;
    final label = _dragLabel;
    final stateNow = current == null ? null : stateOfId(current);

    final Widget stage = current == null
        ? KeyedSubtree(
            key: const ValueKey('done'),
            child: _Done(
              loading: order.isEmpty && src.analyzing,
              empty: order.isEmpty && !src.analyzing,
              pile: pile.length,
              busy: _busy,
              onSend: () => _sendTrash(pile, src),
              onLeave: () => Navigator.of(context).maybePop(),
            ),
          )
        : KeyedSubtree(
            key: ValueKey(current),
            child: Transform.translate(
              offset: _drag,
              child: AnimatedScale(
                scale: _zoom,
                duration: Duration(milliseconds: _zooming ? 0 : 180),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LargePhoto(entity: entities[current]),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (inPile(current))
                            const _Chip('정리 줄', dark: true)
                          else if (stateNow == DecisionState.keep)
                            const _Chip('킵', dark: true)
                          else if (stateNow == DecisionState.hold)
                            const _Chip('보류', dark: true),
                          if (src.notes[current] case final n?) _Chip(n),
                        ],
                      ),
                    ),
                    if (label != null)
                      Center(child: _Chip(label, dark: true, big: true)),
                  ],
                ),
              ),
            ),
          );

    // 뒤로 가기(버튼·제스처·왼쪽 가장자리 밀기)를 막지 않고, 나갈 때 안내만 한다
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _noteOnLeave(pile.length);
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '남은 ${formatCount(left.length)}장 · '
                            '전체 ${formatCount(order.length)}장',
                            style: const TextStyle(
                              fontSize: 12,
                              color: MehhColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.kind == SortKind.screenshots && current != null)
                      IconButton(
                        tooltip: '다른 앱으로 보내기',
                        onPressed: () =>
                            ref.read(photoLibraryProvider).share([current]),
                        icon: const Icon(
                          Icons.ios_share,
                          size: 20,
                          color: MehhColors.text,
                        ),
                      ),
                    IconButton(
                      tooltip: '되돌리기',
                      onPressed: _undo.isEmpty ? null : _undoLast,
                      icon: const Icon(Icons.undo, size: 20),
                      color: MehhColors.text,
                      disabledColor: MehhColors.border,
                    ),
                  ],
                ),
                if (src.summary != null || src.analyzing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                    child: Text(
                      src.analyzing ? '사진을 살펴보는 중이에요' : src.summary!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MehhColors.textMuted,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                _Strip(
                  label: '남은',
                  ids: left,
                  current: current,
                  empty: '다 골랐어요',
                  entities: entities,
                  onTap: _goTo,
                ),
                const SizedBox(height: 6),
                _Strip(
                  label: '보류',
                  ids: holds,
                  current: current,
                  empty: '↑ 위로 올리면 여기로',
                  entities: entities,
                  onTap: _goTo,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Semantics(
                    label: '사진. 위로 밀면 보류, 아래로 밀면 킵, 왼쪽으로 밀면 정리',
                    customSemanticsActions: {
                      const CustomSemanticsAction(label: '보류'): () =>
                          act('hold'),
                      const CustomSemanticsAction(label: '킵'): () =>
                          act('keep'),
                      const CustomSemanticsAction(label: '정리'): () =>
                          act('trash'),
                      const CustomSemanticsAction(label: '이전 사진'): () =>
                          act('prev'),
                    },
                    child: GestureDetector(
                      onScaleStart: current == null ? null : _onScaleStart,
                      onScaleUpdate: current == null ? null : _onScaleUpdate,
                      onScaleEnd: current == null
                          ? null
                          : (_) => act(_onScaleEnd()),
                      onTap: current == null
                          ? null
                          : () => openPhoto(context, current),
                      child: ClipRect(
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: _dragging ? 0 : 240),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (cur, prev) => Stack(
                            fit: StackFit.expand,
                            children: [...prev, ?cur],
                          ),
                          transitionBuilder: (child, anim) {
                            final incoming =
                                child.key ==
                                (current == null
                                    ? const ValueKey('done')
                                    : ValueKey(current));
                            return SlideTransition(
                              position: Tween(
                                begin: incoming ? inFrom : outTo,
                                end: Offset.zero,
                              ).animate(anim),
                              child: FadeTransition(
                                opacity: anim,
                                child: child,
                              ),
                            );
                          },
                          child: stage,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _Strip(
                  label: '킵',
                  ids: keeps,
                  current: current,
                  empty: '↓ 아래로 내리면 여기로',
                  entities: entities,
                  onTap: _goTo,
                ),
                const SizedBox(height: 6),
                _Strip(
                  label: '정리',
                  ids: pile,
                  current: current,
                  empty: '← 왼쪽으로 밀면 여기로',
                  entities: entities,
                  onTap: _goTo,
                  trailing: pile.isEmpty
                      ? null
                      : TextButton(
                          onPressed: _busy ? null : () => _sendTrash(pile, src),
                          style: TextButton.styleFrom(
                            foregroundColor: MehhColors.black,
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            '휴지통으로',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '↑ 보류 · ↓ 킵 · ← 정리 · → 이전 · 누르면 크게',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: MehhColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 다 골랐을 때 (또는 아직 보여줄 사진이 없을 때)
class _Done extends StatelessWidget {
  const _Done({
    required this.loading,
    required this.empty,
    required this.pile,
    required this.busy,
    required this.onSend,
    required this.onLeave,
  });

  final bool loading;
  final bool empty;
  final int pile;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String detail;
    if (loading) {
      title = '사진을 살펴보는 중이에요';
      detail = '조금만 기다려 주세요.';
    } else if (empty) {
      title = '정리할 사진이 없어요';
      detail = '';
    } else if (pile > 0) {
      title = '다 골랐어요';
      detail = '정리 줄 ${formatCount(pile)}장을 휴지통으로 보낼까요?\n30일 안에 되살릴 수 있어요.';
    } else {
      title = '다 골랐어요';
      detail = '';
    }
    return Container(
      decoration: BoxDecoration(
        color: MehhColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: MehhColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
          if (!loading) ...[
            const SizedBox(height: 20),
            if (pile > 0)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : onSend,
                  child: Text('${formatCount(pile)}장 휴지통으로 보내기'),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onLeave,
                child: const Text('나가기'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 남은·보류·킵·정리 줄. 사진을 누르면 가운데로 불러온다.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.label,
    required this.ids,
    required this.current,
    required this.empty,
    required this.entities,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final List<String> ids;
  final String? current;
  final String empty;
  final Map<String, AssetEntity> entities;
  final void Function(String id) onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formatCount(ids.length),
                  style: const TextStyle(
                    fontSize: 12,
                    color: MehhColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: MehhColors.surface,
                borderRadius: BorderRadius.circular(MehhRadius.button),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: ids.isEmpty
                        ? Center(
                            child: Text(
                              empty,
                              style: const TextStyle(
                                fontSize: 12,
                                color: MehhColors.icon,
                              ),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: ids.length,
                            // 사진이 앞에 새로 들어와도 기존 사진은 다시 커지지 않게
                            findChildIndexCallback: (key) {
                              final i = ids.indexOf((key as ValueKey).value);
                              return i < 0 ? null : i;
                            },
                            itemBuilder: (_, i) {
                              final id = ids[i];
                              return Padding(
                                key: ValueKey(id),
                                padding: const EdgeInsets.only(right: 4),
                                child: _StripThumb(
                                  entity: entities[id],
                                  selected: id == current,
                                  onTap: () => onTap(id),
                                ),
                              );
                            },
                          ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 줄에 새로 들어온 사진은 커지며 들어온다
class _StripThumb extends StatelessWidget {
  const _StripThumb({
    required this.entity,
    required this.selected,
    required this.onTap,
  });

  final AssetEntity? entity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          decoration: BoxDecoration(
            border: selected
                ? Border.all(color: MehhColors.black, width: 2)
                : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: PhotoThumb(entity: entity, radius: 4, size: 132),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.dark = false, this.big = false});

  final String text;
  final bool dark;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: big ? 16 : 8,
        vertical: big ? 8 : 3,
      ),
      decoration: BoxDecoration(
        color: dark ? MehhColors.black : MehhColors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: big ? 18 : 12,
          fontWeight: dark ? FontWeight.w500 : FontWeight.w400,
          color: dark ? MehhColors.white : MehhColors.text,
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

/// 똑같은 사진 묶음 수 (홈 카드용)
int duplicateCount(List<DuplicateSet>? sets) =>
    sets?.fold<int>(0, (n, s) => n + s.remove.length) ?? 0;
