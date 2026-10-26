import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../l10n/l10n.dart';
import '../logic/format.dart';
import '../models/day_group.dart';
import '../models/decision.dart';
import '../providers.dart';
import '../theme.dart';
import 'freed_bar.dart';
import 'hold_to_finish.dart';
import 'photo_viewer.dart';
import 'sort_source.dart';
import 'widgets.dart';

/// 크게 보기: 위로 밀면 정리, 아래로 밀면 킵 (위·아래에 같은 모양의 줄, 눌러도 된다).
/// 잘못 정했으면 반대로 밀면 된다. 좌우는 이전·다음 이동만 (끝에서 처음으로 이어짐).
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

  /// 길게 누르면: X 친 사진이 있으면 "N장을 휴지통으로 보내고 끝낼까요?",
  /// 없으면 "끝낼까요?". 보내기로 하면 정리 화면으로 돌아가 바로 보낸다
  Future<void> _finish(int total, int marked) async {
    final l = context.l;
    final ok = await askMehh(
      context,
      // 제목 = 아래 버튼과 같은 말 "N장 휴지통으로" (2026-10-24 Sophie: 반복되는 말 없이)
      title: marked > 0
          ? (widget.kind == SortKind.videos
                ? l.trashCountVideos(marked)
                : l.trashCount(marked))
          : widget.kind == SortKind.videos
          ? l.focusFinishNoneVideos
          : l.focusFinishNone,
      no: l.focusKeepLooking,
      yes: marked > 0 ? l.toTrash : l.focusFinishYes,
    );
    if (ok && mounted) Navigator.of(context).pop(marked > 0);
  }

  void _go(List<String> ids, int step, _Motion motion) {
    if (ids.isEmpty) return;
    final i = ids.indexOf(_currentId);
    final next = ids[((i < 0 ? 0 : i) + step) % ids.length];
    setState(() {
      _motion = motion;
      _currentId = next;
    });
  }

  /// 정하고 다음 사진으로
  Future<void> _decide(List<String> ids, DecisionState s) async {
    await ref.read(decisionsProvider.notifier).set([_currentId], s);
    if (!mounted) return;
    _go(ids, 1, s == DecisionState.keep ? _Motion.down : _Motion.up);
  }

  /// 같은 손동작은 언제나 같은 결과 (CLAUDE.md): 위로 = 정리, 아래로 = 킵.
  /// 잘못 했으면 반대로 밀면 된다.
  void _up(List<String> ids) => _decide(ids, DecisionState.toTrash);

  void _down(List<String> ids) => _decide(ids, DecisionState.keep);

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

  void _onScaleEnd(List<String> ids) {
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
      _up(ids);
    } else if (d.dy > 90) {
      _down(ids);
    } else if (d.dx < -70) {
      _go(ids, 1, _Motion.next);
    } else if (d.dx > 70) {
      _go(ids, -1, _Motion.prev);
    }
  }

  String? _dragLabel(L10n l) {
    if (_drag.dy < -40) return l.pile;
    if (_drag.dy > 40) return l.keep;
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
    final video = widget.kind == SortKind.videos
        ? src.photos.where((p) => p.id == current && p.isVideo).firstOrNull
        : null;
    final marked = isMarked(current, decisions, src);
    final state = stateOf(decisions, current);
    final (inFrom, outTo) = _slide;
    final kept = state == DecisionState.keep;
    final label = _dragLabel(l);
    final markedCount = ids.where((id) => isMarked(id, decisions, src)).length;

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
                    // 큰 동영상: 첫 장면만 보이니 무엇인지 알 수 있게 길이·용량·날짜 (UX-49)
                    if (video != null)
                      _Chip(
                        '${formatDuration(video.durationSec)} · '
                        '${formatBytes(video.sizeBytes)} · '
                        '${formatDate(video.takenAt, l.localeName)}',
                      ),
                  ],
                ),
              ),
              if (label != null)
                Center(child: _Chip(label, dark: true, big: true))
              // 큰 동영상: ▶ → 갤러리에서 재생 (2026-10-26 Sophie V3-A)
              else if (video != null)
                Center(child: _PlayButton(id: video.id)),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      // 손대면 "가만히 있음" 시간을 처음부터
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Column(
            children: [
              // 위치는 아래 사진 줄이 보여 주므로 "3 / 214" 숫자는 두지 않는다.
              // 되돌리기 버튼도 두지 않는다: 반대로 밀면 된다 (2026-10-22)
              MehhHeader.top(
                leading: const MehhBackButton(),
                trailing: const [MehhTopActions()],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _ActionBar(
                  // 위로 끌수록 채워진다 (90px에서 꽉 참)
                  fill: (-_drag.dy / 90).clamp(0.0, 1.0),
                  icon: Icons.delete_outline,
                  label: l.pile,
                  semantics: l.trashBarSemantics,
                  onTap: () => _up(ids),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Semantics(
                    label: l.photoSemantics,
                    customSemanticsActions: {
                      CustomSemanticsAction(label: l.pile): () => _up(ids),
                      CustomSemanticsAction(label: l.keep): () => _down(ids),
                      CustomSemanticsAction(label: l.nextPhoto): () =>
                          _go(ids, 1, _Motion.next),
                      CustomSemanticsAction(label: l.prevPhoto): () =>
                          _go(ids, -1, _Motion.prev),
                      CustomSemanticsAction(
                        label: l.focusFinishSemantics,
                      ): () =>
                          _finish(ids.length, markedCount),
                    },
                    // 길게 누르기 = 언제나 "정리 끝내기" (정리 화면 그리드와 같은 [HoldToFinish])
                    child: HoldToFinish(
                      armed: markedCount > 0,
                      onDone: () => _finish(ids.length, markedCount),
                      child: GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        onScaleEnd: (_) => _onScaleEnd(ids),
                        onTap: () => openPhoto(context, current),
                        child: ClipRect(
                          child: AnimatedSwitcher(
                            duration: Duration(
                              milliseconds: _dragging ? 0 : 220,
                            ),
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
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _ActionBar(
                  // 아래로 끌수록 채워진다 (위쪽 정리 줄과 같은 모양)
                  fill: (_drag.dy / 90).clamp(0.0, 1.0),
                  icon: Icons.check,
                  label: l.keep,
                  semantics: l.keepBarSemantics,
                  onTap: () => _down(ids),
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
                  radius: MehhRadius.strip,
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

/// 위 정리 줄·아래 킵 줄: 사진을 그쪽으로 끌면 점점 검게 채워진다. 눌러도 된다.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.fill,
    required this.icon,
    required this.label,
    required this.semantics,
    required this.onTap,
  });

  final double fill;
  final IconData icon;
  final String label;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = Color.lerp(MehhColors.surface, MehhColors.black, fill)!;
    final fg = Color.lerp(MehhColors.text, MehhColors.white, fill)!;
    return Semantics(
      button: true,
      label: semantics,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(MehhRadius.card),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
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

/// 큰 동영상 가운데 ▶. 누르면 갤러리(기본 동영상 앱)에서 그 영상을 연다
class _PlayButton extends ConsumerWidget {
  const _PlayButton({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    return Material(
      color: MehhColors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: l.playVideo,
        iconSize: 40,
        padding: const EdgeInsets.all(12),
        color: MehhColors.white,
        icon: const Icon(Icons.play_arrow_rounded),
        onPressed: () async {
          final ok = await ref.read(deviceProvider).openVideo(id);
          if (!ok && context.mounted) showNote(context, l.videoOpenFailed);
        },
      ),
    );
  }
}
