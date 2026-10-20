import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/day_group.dart';
import '../models/decision.dart';
import '../providers.dart';
import '../theme.dart';
import 'photo_viewer.dart';
import 'sort_source.dart';
import 'strings.dart';
import 'widgets.dart';

/// 크게 보기: 위로 밀면 정리, 아래로 밀면 킵, 좌우는 이전·다음 (끝에서 처음으로 이어짐).
/// 정하지 않고 옆으로 넘긴 사진은 자동으로 보류 (애매하면 그냥 넘기면 된다. 30일 뒤 다시 물어봄).
/// 아래 한 줄 사진 줄이 지금 위치와 각 사진의 상태(정리 = 흐리게 + X, 킵 = 체크)를 보여 준다.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({
    super.key,
    required this.kind,
    required this.initialId,
    this.group,
    this.place,
  });

  final SortKind kind;
  final DayGroup? group;
  final String? place;
  final String initialId;

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _Undo {
  const _Undo(this.before, this.id);
  final Map<String, Decision?> before;
  final String id;
}

/// 사진이 들어오고 나가는 방향
enum _Motion { next, prev, up, down }

class _FocusScreenState extends ConsumerState<FocusScreen> {
  late String _currentId = widget.initialId;

  Offset _drag = Offset.zero;
  Offset _raw = Offset.zero;
  Axis? _axis;
  bool _dragging = false;
  bool _zooming = false;
  double _zoom = 1;

  _Motion _motion = _Motion.next;
  final _undo = <_Undo>[];

  void _go(List<String> ids, int step, _Motion motion) {
    if (ids.isEmpty) return;
    final i = ids.indexOf(_currentId);
    final next = ids[((i < 0 ? 0 : i) + step) % ids.length];
    setState(() {
      _motion = motion;
      _currentId = next;
    });
  }

  Future<void> _decide(List<String> ids, DecisionState s) async {
    final id = _currentId;
    final before = await ref.read(decisionsProvider.notifier).set([id], s);
    _undo.add(_Undo(before, id));
    if (!mounted) return;
    _go(ids, 1, switch (s) {
      DecisionState.keep => _Motion.down,
      DecisionState.hold => _Motion.next,
      _ => _Motion.up,
    });
  }

  Future<void> _undoLast() async {
    if (_undo.isEmpty) return;
    final u = _undo.removeLast();
    await ref.read(decisionsProvider.notifier).restore(u.before);
    if (!mounted) return;
    setState(() {
      _motion = _Motion.prev;
      _currentId = u.id;
    });
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

  /// [autoHold]: 지금 사진을 아직 정하지 않았으면 다음으로 넘길 때 보류로
  void _onScaleEnd(List<String> ids, bool autoHold) {
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
    if (wasZoom) return;
    if (d.dy < -90) {
      _decide(ids, DecisionState.toTrash);
    } else if (d.dy > 90) {
      _decide(ids, DecisionState.keep);
    } else if (d.dx < -70) {
      autoHold ? _decide(ids, DecisionState.hold) : _go(ids, 1, _Motion.next);
    } else if (d.dx > 70) {
      _go(ids, -1, _Motion.prev);
    }
  }

  String? get _dragLabel {
    if (_drag.dy < -40) return Terms.pile;
    if (_drag.dy > 40) return Terms.keep;
    return null;
  }

  (Offset, Offset) get _slide => switch (_motion) {
    _Motion.next => (const Offset(1, 0), const Offset(-1, 0)),
    _Motion.prev => (const Offset(-1, 0), const Offset(1, 0)),
    _Motion.up => (const Offset(1, 0), const Offset(0, -1.1)),
    _Motion.down => (const Offset(1, 0), const Offset(0, 1.1)),
  };

  @override
  Widget build(BuildContext context) {
    final src = watchSortSource(ref, widget.kind, widget.group);
    final decisions = ref.watch(decisionsProvider).value ?? const {};
    final entities = ref.read(photoLibraryProvider).entities;
    final ids = [
      for (final p in src.photos)
        if (stateOf(decisions, p.id) != DecisionState.trashed) p.id,
    ];
    if (ids.isEmpty) return const Scaffold();
    final current = ids.contains(_currentId) ? _currentId : ids.first;
    final index = ids.indexOf(current);
    final marked = isMarked(current, decisions, src);
    final state = stateOf(decisions, current);
    final (inFrom, outTo) = _slide;
    final label = _dragLabel;

    final card = KeyedSubtree(
      key: ValueKey(current),
      child: Transform.translate(
        offset: _drag,
        child: AnimatedScale(
          scale: _zoom,
          duration: Duration(milliseconds: _zooming ? 0 : 180),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: marked ? 0.55 : 1,
                child: LargePhoto(entity: entities[current]),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (marked)
                      const _Chip('✕ ${Terms.pile}', dark: true)
                    else if (state == DecisionState.keep)
                      const _Chip('✓ ${Terms.keep}', dark: true)
                    else if (state == DecisionState.hold)
                      const _Chip(Terms.hold, dark: true),
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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Column(
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
                    child: Text(
                      '${index + 1} / ${ids.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: MehhColors.textMuted,
                      ),
                    ),
                  ),
                  if (widget.kind == SortKind.screenshots &&
                      (ref.watch(cortexInstalledProvider).value ?? false))
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await ref
                            .read(handoffProvider)
                            .sendToCortex(current);
                        if (!ok && context.mounted) {
                          showNote(context, 'Cortex로 보내지 못했어요');
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: MehhColors.text,
                        minimumSize: const Size(44, 44),
                      ),
                      icon: const Icon(Icons.north_east, size: 16),
                      label: const Text('Cortex로 보내기'),
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
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _TrashBar(
                  // 위로 끌수록 채워진다 (90px에서 꽉 참)
                  fill: (-_drag.dy / 90).clamp(0.0, 1.0),
                  marked: marked,
                  onTap: () => _decide(ids, DecisionState.toTrash),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Semantics(
                    label: '사진. 위로 밀면 정리, 아래로 밀면 킵',
                    customSemanticsActions: {
                      const CustomSemanticsAction(label: Terms.pile): () =>
                          _decide(ids, DecisionState.toTrash),
                      const CustomSemanticsAction(label: Terms.keep): () =>
                          _decide(ids, DecisionState.keep),
                      const CustomSemanticsAction(label: '다음 사진'): () =>
                          _go(ids, 1, _Motion.next),
                      const CustomSemanticsAction(label: '이전 사진'): () =>
                          _go(ids, -1, _Motion.prev),
                    },
                    child: GestureDetector(
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      onScaleEnd: (_) => _onScaleEnd(
                        ids,
                        state == DecisionState.undecided && !marked,
                      ),
                      onTap: () => openPhoto(context, current),
                      child: ClipRect(
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: _dragging ? 0 : 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (cur, prev) => Stack(
                            fit: StackFit.expand,
                            children: [...prev, ?cur],
                          ),
                          transitionBuilder: (child, anim) {
                            final incoming = child.key == ValueKey(current);
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
              ),
              const SizedBox(height: 12),
              _LoopStrip(
                ids: ids,
                current: current,
                entities: entities,
                stateOf: (id) => isMarked(id, decisions, src)
                    ? DecisionState.toTrash
                    : stateOf(decisions, id),
                onTap: (id) => setState(() {
                  _motion = ids.indexOf(id) < index
                      ? _Motion.prev
                      : _Motion.next;
                  _currentId = id;
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 아래 한 줄 사진 줄. 끝에서 계속 밀면 처음으로 이어진다 (무한 반복).
/// 지금 사진은 테두리, 정리할 사진은 흐리게 + X, 킵은 체크.
class _LoopStrip extends StatefulWidget {
  const _LoopStrip({
    required this.ids,
    required this.current,
    required this.entities,
    required this.stateOf,
    required this.onTap,
  });

  final List<String> ids;
  final String current;
  final Map<String, AssetEntity> entities;
  final DecisionState Function(String id) stateOf;
  final void Function(String id) onTap;

  @override
  State<_LoopStrip> createState() => _LoopStripState();
}

class _LoopStripState extends State<_LoopStrip> {
  static const _extent = 54.0; // 칸 50 + 간격 4
  static const _laps = 2000; // 이만큼 반복해서 사실상 끝이 없다

  ScrollController? _scroll;
  double _width = 0;

  int get _n => widget.ids.length;

  /// 화면 가운데에 [index]번째 칸이 오는 위치
  double _offsetFor(int index) => index * _extent - (_width - _extent) / 2;

  /// 지금 보이는 위치에서 가장 가까운 [id] 칸
  int _nearestIndexOf(String id) {
    final i = widget.ids.indexOf(id);
    final s = _scroll;
    final center = s != null && s.hasClients
        ? (s.offset + (_width - _extent) / 2) / _extent
        : (_laps ~/ 2) * _n.toDouble();
    final lap = (center / _n).floor();
    final candidates = [
      for (final l in [lap - 1, lap, lap + 1]) l * _n + i,
    ];
    candidates.sort((a, b) => (a - center).abs().compareTo((b - center).abs()));
    return candidates.first;
  }

  @override
  void didUpdateWidget(_LoopStrip old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current || old.ids.length != widget.ids.length) {
      final s = _scroll;
      if (s != null && s.hasClients) {
        s.animateTo(
          _offsetFor(_nearestIndexOf(widget.current)),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: LayoutBuilder(
        builder: (context, box) {
          _width = box.maxWidth;
          _scroll ??= ScrollController(
            initialScrollOffset: _offsetFor(
              (_laps ~/ 2) * _n + widget.ids.indexOf(widget.current),
            ),
          );
          return ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            itemExtent: _extent,
            itemCount: _n * _laps,
            itemBuilder: (_, i) {
              final id = widget.ids[i % _n];
              final s = widget.stateOf(id);
              final out = s == DecisionState.toTrash;
              final selected = id == widget.current;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () => widget.onTap(id),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected ? MehhColors.black : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(MehhRadius.thumb),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: out ? 0.35 : 1,
                          child: PhotoThumb(
                            entity: widget.entities[id],
                            radius: 4,
                            size: 150,
                          ),
                        ),
                        if (out)
                          const Positioned(right: 2, top: 2, child: XMark()),
                        if (s == DecisionState.keep)
                          const Positioned(right: 2, top: 2, child: _Check()),
                        if (s == DecisionState.hold)
                          const Positioned(
                            right: 2,
                            top: 2,
                            child: Icon(
                              Icons.schedule,
                              size: 14,
                              color: MehhColors.black,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: MehhColors.white,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 12, color: MehhColors.black),
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

/// 맨 위 쓰레기통 줄: 사진을 위로 끌면 점점 검게 채워진다. 눌러도 정리.
class _TrashBar extends StatelessWidget {
  const _TrashBar({
    required this.fill,
    required this.marked,
    required this.onTap,
  });

  final double fill;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = Color.lerp(MehhColors.surface, MehhColors.black, fill)!;
    final fg = Color.lerp(MehhColors.text, MehhColors.white, fill)!;
    return Semantics(
      button: true,
      label: '${Terms.pile}. 사진을 위로 올려도 돼요',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(MehhRadius.card),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline, size: 22, color: fg),
              const SizedBox(width: 6),
              Text(
                marked ? '${Terms.pile}할 사진' : Terms.pile,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
