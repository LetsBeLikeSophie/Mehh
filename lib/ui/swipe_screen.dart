import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/recommend.dart';
import '../models/day_group.dart';
import '../models/decision.dart';
import '../models/photo_meta.dart';
import '../providers.dart';
import '../theme.dart';
import 'photo_viewer.dart';
import 'widgets.dart';

/// 하나씩 넘기기 (SPEC 5-3). 버튼 없이 밀어서 결정한다.
/// 위 = 보류, 아래 = 킵, 왼쪽 = 정리, 오른쪽 = 이전 사진.
/// 정리로 고른 사진은 화면을 나갈 때 한 번의 확인으로 휴지통에 보낸다.
class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key, required this.group});

  final DayGroup group;

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _Undo {
  const _Undo(this.before, this.trashed, this.burst, this.index);
  final Map<String, Decision?> before;
  final String? trashed;
  final int burst;
  final int index;
}

/// 사진이 들어오고 나가는 방향
enum _Motion { next, prev, keep, hold, trash }

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  late final List<List<PhotoMeta>> _bursts;
  int _b = 0, _i = 0;

  /// 끌고 있는 거리. 처음 움직인 방향(가로/세로) 한 축으로만 움직인다.
  Offset _drag = Offset.zero;
  Offset _raw = Offset.zero;
  Axis? _axis;
  bool _dragging = false;

  _Motion _motion = _Motion.next;
  final _undo = <_Undo>[];

  /// 정리하기로 고른 사진 (나갈 때 휴지통으로)
  final _pending = <String>{};
  bool _leaving = false;

  bool get _perPhoto => widget.group.kind != DayGroupKind.day;

  @override
  void initState() {
    super.initState();
    _bursts = _perPhoto
        ? [
            for (final p in widget.group.photos.reversed) [p],
          ]
        : ref.read(groupPlanProvider(widget.group)).bursts;
    // 아직 결정 안 한 사진부터
    final decisions = ref.read(decisionsProvider).value ?? const {};
    for (var b = 0; b < _bursts.length; b++) {
      final i = _bursts[b].indexWhere(
        (p) => stateOf(decisions, p.id) == DecisionState.undecided,
      );
      if (i >= 0) {
        _b = b;
        _i = i;
        break;
      }
    }
  }

  PhotoMeta get _current => _bursts[_b][_i];

  bool get _isLast => _b == _bursts.length - 1 && _i == _bursts[_b].length - 1;

  Iterable<PhotoMeta> get _all => _bursts.expand((b) => b);

  void _move(int step, {_Motion? motion}) {
    var b = _b, i = _i + step;
    if (i >= _bursts[b].length) {
      if (b + 1 >= _bursts.length) return;
      b++;
      i = 0;
    } else if (i < 0) {
      if (b == 0) return;
      b--;
      i = _bursts[b].length - 1;
    }
    setState(() {
      _motion = motion ?? (step > 0 ? _Motion.next : _Motion.prev);
      _b = b;
      _i = i;
    });
  }

  void _jump(int i) {
    if (i == _i) return;
    setState(() {
      _motion = i > _i ? _Motion.next : _Motion.prev;
      _i = i;
    });
  }

  Future<void> _decide(DecisionState s) async {
    final id = _current.id;
    final before = await ref.read(decisionsProvider.notifier).set([id], s);
    _pending.remove(id);
    _undo.add(_Undo(before, null, _b, _i));
    if (!mounted) return;
    if (_isLast) return _leave();
    _move(1, motion: s == DecisionState.hold ? _Motion.hold : _Motion.keep);
  }

  void _markTrash() {
    final id = _current.id;
    _pending.add(id);
    _undo.add(_Undo(const {}, id, _b, _i));
    if (_isLast) {
      setState(() {});
      _leave();
      return;
    }
    _move(1, motion: _Motion.trash);
  }

  Future<void> _undoLast() async {
    if (_undo.isEmpty) return;
    final u = _undo.removeLast();
    if (u.trashed != null) {
      _pending.remove(u.trashed);
    } else {
      await ref.read(decisionsProvider.notifier).restore(u.before);
    }
    if (!mounted) return;
    setState(() {
      _motion = _Motion.prev;
      _b = u.burst;
      _i = u.index;
    });
  }

  /// 저장 상태를 알려주고, 고른 사진은 한 번에 휴지통으로 보낸 뒤 나간다
  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final decisions = ref.read(decisionsProvider).value ?? const {};
    final c = _counts(decisions);
    var note = '킵 ${c.keep} · 보류 ${c.hold} 저장했어요';
    if (_pending.isNotEmpty) {
      final n = await ref.read(cleanerProvider).trash(_pending);
      note = n > 0 ? '$note · ${formatCount(n)}장 휴지통으로' : '$note · 정리는 취소했어요';
    }
    if (!mounted) return;
    showNote(context, note);
    Navigator.of(context).pop();
  }

  ({int keep, int hold, int trash, int left}) _counts(
    Map<String, Decision> decisions,
  ) {
    var keep = 0, hold = 0, left = 0;
    for (final p in _all) {
      if (_pending.contains(p.id)) continue;
      switch (stateOf(decisions, p.id)) {
        case DecisionState.keep:
          keep++;
        case DecisionState.hold:
          hold++;
        case DecisionState.undecided:
          left++;
        case DecisionState.trashed:
          break;
      }
    }
    return (keep: keep, hold: hold, trash: _pending.length, left: left);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _raw += d.delta;
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

  void _onPanEnd(DragEndDetails _) {
    final d = _drag;
    setState(() {
      _drag = Offset.zero;
      _raw = Offset.zero;
      _axis = null;
      _dragging = false;
    });
    if (d.dy < -90) {
      _decide(DecisionState.hold);
    } else if (d.dy > 90) {
      _decide(DecisionState.keep);
    } else if (d.dx < -80) {
      _markTrash();
    } else if (d.dx > 80) {
      _move(-1);
    }
  }

  String? get _dragLabel {
    if (_drag.dy < -40) return '보류';
    if (_drag.dy > 40) return '킵';
    if (_drag.dx < -40) return '정리';
    if (_drag.dx > 40) return '이전 사진';
    return null;
  }

  /// 들어오는 사진의 시작 위치, 나가는 사진의 끝 위치
  (Offset, Offset) get _slide => switch (_motion) {
    _Motion.next => (const Offset(1, 0), const Offset(-1, 0)),
    _Motion.prev => (const Offset(-1, 0), const Offset(1, 0)),
    _Motion.keep => (const Offset(0, -0.15), const Offset(0, 1.1)),
    _Motion.hold => (const Offset(0, 0.15), const Offset(0, -1.1)),
    _Motion.trash => (const Offset(1, 0), const Offset(-1.1, 0)),
  };

  @override
  Widget build(BuildContext context) {
    if (_bursts.isEmpty) return const Scaffold();
    final entities = ref.read(photoLibraryProvider).entities;
    final features = ref.watch(analysisProvider.select((s) => s.features));
    final decisions = ref.watch(decisionsProvider).value ?? const {};
    final plan = ref.watch(groupPlanProvider(widget.group));
    final burst = _bursts[_b];
    final p = _current;
    final state = stateOf(decisions, p.id);
    final isBest = !_perPhoto && plan.best.contains(p.id);
    final (inFrom, outTo) = _slide;
    final c = _counts(decisions);
    final label = _dragLabel;

    final card = KeyedSubtree(
      key: ValueKey(p.id),
      child: Transform.translate(
        offset: _drag,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LargePhoto(entity: entities[p.id]),
            Positioned(
              left: 14,
              bottom: 14,
              right: 14,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (_pending.contains(p.id))
                    const _Chip('정리할 사진', dark: true)
                  else if (isBest) ...[
                    const _Chip('베스트 추천', dark: true),
                    if (bestReason(features[p.id], [
                          for (final q in burst) features[q.id],
                        ])
                        case final r when r.isNotEmpty)
                      _Chip(r),
                  ] else if (plan.trash.containsKey(p.id))
                    const _Chip('정리 추천'),
                  if (state == DecisionState.keep) const _Chip('킵', dark: true),
                  if (state == DecisionState.hold)
                    const _Chip('보류', dark: true),
                ],
              ),
            ),
            if (label != null)
              Center(child: _Chip(label, dark: true, big: true)),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '돌아가기',
                      padding: EdgeInsets.zero,
                      onPressed: _leave,
                      icon: const Icon(
                        Icons.chevron_left,
                        color: MehhColors.text,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            c.left == 0
                                ? '다 봤어요'
                                : '남은 ${formatCount(c.left)}장',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '킵 ${c.keep} · 보류 ${c.hold} · 정리 ${c.trash}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: MehhColors.textMuted,
                            ),
                          ),
                        ],
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
                const SizedBox(height: 6),
                const _Hint('↑ 올리면 보류'),
                const SizedBox(height: 10),
                Expanded(
                  child: Semantics(
                    label: '사진. 위로 밀면 보류, 아래로 밀면 킵, 왼쪽으로 밀면 정리',
                    customSemanticsActions: {
                      const CustomSemanticsAction(label: '보류'): () =>
                          _decide(DecisionState.hold),
                      const CustomSemanticsAction(label: '킵'): () =>
                          _decide(DecisionState.keep),
                      const CustomSemanticsAction(label: '정리'): _markTrash,
                      const CustomSemanticsAction(label: '이전 사진'): () =>
                          _move(-1),
                    },
                    child: GestureDetector(
                      onPanStart: (_) => setState(() => _dragging = true),
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      onTap: () => openPhoto(context, p.id),
                      child: ClipRect(
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: _dragging ? 0 : 240),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (current, previous) => Stack(
                            fit: StackFit.expand,
                            children: [...previous, ?current],
                          ),
                          transitionBuilder: (child, anim) {
                            final incoming = child.key == ValueKey(p.id);
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
                          child: card,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const _Hint('↓ 내리면 킵 · ← 밀면 정리 · → 이전 사진'),
                if (!_perPhoto) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: burst.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 4),
                      itemBuilder: (_, i) {
                        final q = burst[i];
                        final decided =
                            _pending.contains(q.id) ||
                            stateOf(decisions, q.id) != DecisionState.undecided;
                        return GestureDetector(
                          onTap: () => _jump(i),
                          child: Container(
                            width: 40,
                            decoration: BoxDecoration(
                              border: i == _i
                                  ? Border.all(
                                      color: MehhColors.black,
                                      width: 2,
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Opacity(
                              opacity: decided ? 0.45 : 1,
                              child: PhotoThumb(
                                entity: entities[q.id],
                                radius: 4,
                                size: 120,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: MehhColors.textMuted),
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
