import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../l10n/l10n.dart';
import '../models/day_group.dart';
import '../models/decision.dart';
import '../providers.dart';
import '../theme.dart';
import 'photo_viewer.dart';
import 'sort_source.dart';
import 'widgets.dart';

/// 크게 보기: 위로 밀면 정리, 아래로 밀면 킵. 이미 그 상태면 같은 방향으로 한 번 더 = 취소.
/// 좌우는 이전·다음 이동만 (상태는 바뀌지 않음, 끝에서 처음으로 이어짐).
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

  /// 정하고 다음 사진으로. [advance]가 false면(취소할 때) 그 자리에 머문다.
  Future<void> _decide(
    List<String> ids,
    DecisionState s, {
    bool advance = true,
  }) async {
    final id = _currentId;
    final before = await ref.read(decisionsProvider.notifier).set([id], s);
    _undo.add(_Undo(before, id));
    if (!mounted) return;
    if (!advance) {
      setState(() {});
      return;
    }
    _go(ids, 1, s == DecisionState.keep ? _Motion.down : _Motion.up);
  }

  /// 위로: 정리. 이미 정리면 취소 (추천 사진이면 킵, 아니면 표시 없음)
  void _up(List<String> ids, {required bool marked, required bool suggested}) {
    if (!marked) {
      _decide(ids, DecisionState.toTrash);
    } else {
      _decide(
        ids,
        suggested ? DecisionState.keep : DecisionState.undecided,
        advance: false,
      );
    }
  }

  /// 아래로: 킵. 이미 킵이면 취소 (표시 없음, 추천 사진이면 다시 X)
  void _down(List<String> ids, {required bool kept}) => kept
      ? _decide(ids, DecisionState.undecided, advance: false)
      : _decide(ids, DecisionState.keep);

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

  void _onScaleEnd(
    List<String> ids, {
    required bool marked,
    required bool kept,
    required bool suggested,
  }) {
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
      _up(ids, marked: marked, suggested: suggested);
    } else if (d.dy > 90) {
      _down(ids, kept: kept);
    } else if (d.dx < -70) {
      _go(ids, 1, _Motion.next);
    } else if (d.dx > 70) {
      _go(ids, -1, _Motion.prev);
    }
  }

  String? _dragLabel(L10n l, {required bool marked, required bool kept}) {
    if (_drag.dy < -40) return marked ? l.pileCancel : l.pile;
    if (_drag.dy > 40) return kept ? l.keepCancel : l.keep;
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
    final l = context.l;
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
    final kept = state == DecisionState.keep;
    final suggested = src.suggested.contains(current);
    final label = _dragLabel(l, marked: marked, kept: kept);

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
                      _Chip('✕ ${l.pile}', dark: true)
                    else if (kept)
                      _Chip('✓ ${l.keep}', dark: true),
                    if (src.tags[current] case final t?)
                      _Chip(
                        noteText(t, src.bestReasons[current] ?? const [], l),
                      ),
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
                    tooltip: l.back,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.chevron_left,
                      color: MehhColors.text,
                    ),
                  ),
                  // 위치는 아래 사진 줄이 보여 주므로 "3 / 214" 숫자는 두지 않는다
                  const Spacer(),
                  if (widget.kind == SortKind.screenshots &&
                      (ref.watch(cortexInstalledProvider).value ?? false))
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await ref
                            .read(handoffProvider)
                            .sendToCortex(current);
                        if (!context.mounted) return;
                        if (!ok) {
                          showNote(context, l.cortexFailed);
                          return;
                        }
                        // 보낸 캡처는 정리(X)에 넣는다. 지우는 건 [휴지통으로]를 눌러야 하고,
                        // 잘못 넣었으면 되돌리기나 X로 바로 뺄 수 있다.
                        if (!marked) {
                          await _decide(ids, DecisionState.toTrash);
                        }
                        if (context.mounted) {
                          showNote(context, l.cortexSent);
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: MehhColors.text,
                        minimumSize: const Size(44, 44),
                      ),
                      icon: const Icon(Icons.north_east, size: 16),
                      label: Text(l.sendToCortex),
                    ),
                  IconButton(
                    tooltip: l.undo,
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
                  onTap: () => _up(ids, marked: marked, suggested: suggested),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Semantics(
                    label: l.photoSemantics,
                    customSemanticsActions: {
                      CustomSemanticsAction(label: l.pile): () =>
                          _up(ids, marked: marked, suggested: suggested),
                      CustomSemanticsAction(label: l.keep): () =>
                          _down(ids, kept: kept),
                      CustomSemanticsAction(label: l.nextPhoto): () =>
                          _go(ids, 1, _Motion.next),
                      CustomSemanticsAction(label: l.prevPhoto): () =>
                          _go(ids, -1, _Motion.prev),
                    },
                    child: GestureDetector(
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      onScaleEnd: (_) => _onScaleEnd(
                        ids,
                        marked: marked,
                        kept: kept,
                        suggested: suggested,
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

/// 아래 한 줄 사진 줄. 화면보다 많으면 끝에서 처음으로 이어지며 돈다 (무한 반복),
/// 다 들어가면 실제 장수만 보여 준다.
/// 지금 사진은 테두리, 정리할 사진은 흐리게 + X, 킵은 체크, 정하지 않은 사진은 표시 없음.
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
          // 화면에 다 들어가면 실제 장수만 보여 준다 (반복해서 채우지 않음)
          if (_n * _extent <= box.maxWidth) {
            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final id in widget.ids)
                    SizedBox(width: _extent, child: _tile(id)),
                ],
              ),
            );
          }
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
            itemBuilder: (_, i) => _tile(widget.ids[i % _n]),
          );
        },
      ),
    );
  }

  Widget _tile(String id) {
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
              if (out) const Positioned(right: 2, top: 2, child: XMark()),
              if (s == DecisionState.keep)
                const Positioned(right: 2, top: 2, child: _Check()),
            ],
          ),
        ),
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
        borderRadius: BorderRadius.circular(MehhRadius.chip),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: big ? MehhText.heading : MehhText.label,
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
      label: context.l.trashBarSemantics,
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
                marked ? context.l.pileCancel : context.l.pile,
                style: TextStyle(
                  fontSize: MehhText.bodySmall,
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
