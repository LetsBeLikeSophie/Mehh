import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/pro.dart';
import '../l10n/l10n.dart';
import '../logic/format.dart';
import '../logic/recommend.dart';
import '../models/day_group.dart';
import '../models/decision.dart';
import '../providers.dart';
import '../theme.dart';
import 'freed_bar.dart';
import 'pro_sheet.dart';
import 'settings_screen.dart';
import 'sort_screen.dart';
import 'widgets.dart';

/// 홈: 중복 카드 + 그날의 묶음 목록 (최신순, 연도별 구분선).
/// 연도가 2개 이상이면 오른쪽 연도 레일로 앨범처럼 연도 사이를 오간다.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

/// 목록 한 줄: 연도 구분선 또는 묶음
sealed class _Entry {}

class _YearEntry extends _Entry {
  _YearEntry(this.year);
  final int year;
}

class _GroupEntry extends _Entry {
  _GroupEntry(this.group);
  final DayGroup group;
}

const _yearExtent = 48.0;
const _tileExtent = 69.0;
const _railWidth = 32.0;

class _HomeTabState extends ConsumerState<HomeTab> {
  final _scroll = ScrollController();
  final _daysKey = GlobalKey();
  List<_Entry> _entries = const [];
  List<double> _offsets = const []; // 각 줄의 시작 위치 (목록 안에서)
  int? _currentYear;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateYear);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 묶음 목록이 스크롤 안에서 시작하는 위치
  double? get _daysStart {
    final ro = _daysKey.currentContext?.findRenderObject();
    return ro is RenderSliver ? ro.constraints.precedingScrollExtent : null;
  }

  int _indexAt(double y) {
    var lo = 0, hi = _offsets.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_offsets[mid] <= y) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  void _updateYear() {
    final start = _daysStart;
    if (start == null || _entries.isEmpty) return;
    final year = switch (_entries[_indexAt(_scroll.offset - start + 1)]) {
      _YearEntry(:final year) => year,
      _GroupEntry(:final group) => group.start.year,
    };
    if (year != _currentYear) setState(() => _currentYear = year);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    ref.listen(yearlyEndedProvider, (_, ended) {
      if (!ended) return;
      ref.read(yearlyEndedProvider.notifier).clear();
      showNote(context, l.yearlyEnded(freeGroupsPerMonth));
    });
    ref.listen(freeRefilledProvider, (_, refilled) {
      if (!refilled) return;
      ref.read(freeRefilledProvider.notifier).clear();
      showNote(context, l.freeRefilled(freeGroupsPerMonth));
    });
    ref.listen(proStartedProvider, (_, started) {
      if (!started) return;
      ref.read(proStartedProvider.notifier).clear();
      showNote(context, l.proThanks);
    });
    final library = ref.watch(libraryProvider);
    final limited = ref.watch(permissionProvider) == PermissionState.limited;

    return SafeArea(
      bottom: false,
      child: library.when(
        loading: () => _Message(l.loadingGroups),
        error: (e, _) => _Message(
          l.loadFailed,
          action: (l.retry, () => ref.read(libraryProvider.notifier).reload()),
        ),
        data: (state) {
          if (state.groups.isEmpty) return _Message(l.noPhotos);
          final days = [
            for (final g in state.groups)
              if (g.kind == DayGroupKind.day) g,
          ];
          final others = [
            for (final g in state.groups)
              if (g.kind != DayGroupKind.day) g,
          ];
          final left = days
              .where(
                (g) =>
                    ref.watch(groupStatusProvider(g)) == GroupStatus.needsWork,
              )
              .length;

          // 연도 구분선을 끼운 목록과 각 줄의 위치
          final entries = <_Entry>[];
          int? lastYear;
          for (final g in days) {
            final y = g.start.year;
            if (y != lastYear) entries.add(_YearEntry(y));
            lastYear = y;
            entries.add(_GroupEntry(g));
          }
          final offsets = <double>[];
          var acc = 0.0;
          for (final e in entries) {
            offsets.add(acc);
            acc += e is _YearEntry ? _yearExtent : _tileExtent;
          }
          _entries = entries;
          _offsets = offsets;
          final years = [
            for (final e in entries)
              if (e is _YearEntry) e.year,
          ];
          final rail = years.length > 1;
          final right = rail ? 12.0 + _railWidth : 20.0;
          final bottom = MediaQuery.paddingOf(context).bottom + 48;

          final list = CustomScrollView(
            controller: _scroll,
            slivers: [
              // 로고·Pro·설정 줄은 연도 레일과 상관없이 오른쪽 끝에 붙인다
              // (아이콘 버튼 자체 여백이 있어서 8만 둔다)
              SliverPadding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 12, 0),
                sliver: SliverToBoxAdapter(
                  // 염소는 크게 (2026-10-24 Sophie: 큰 글씨 위에 존재감 있게)
                  child: MehhHeader.top(
                    leading: const MehhLogo(height: 56),
                    trailing: [
                      const ProChip(),
                      MehhHeader.icon(
                        tooltip: l.settings,
                        icon: Icons.settings_outlined,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                      // 맨 오른쪽 갤러리는 정리 화면과 같은 자리
                      const GalleryButton(),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, right, 0),
                sliver: SliverList.list(
                  children: [
                    // 제목 칸은 정리 화면과 같은 높이: 막대가 같은 자리에 온다
                    MehhHeader.titleBox([
                      Text(
                        left > 0
                            ? l.groupsLeft(left)
                            // 분석이 끝나기 전에는 "없어요"라고 하지 않는다 (UX 리뷰 2026-10-22)
                            : ref.watch(analysisProvider.select((a) => a.done))
                            ? l.noGroupsLeft
                            : l.lookingAtPhotos,
                        style: const TextStyle(
                          fontSize: MehhText.display,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const _Subtitle(),
                    ]),
                    const FreedBar(),
                    if (limited) ...[
                      const SizedBox(height: 20),
                      _LimitedBanner(
                        onTap: () async {
                          await ref.read(photoLibraryProvider).presentLimited();
                          ref.read(libraryProvider.notifier).reload();
                        },
                      ),
                    ],
                    const _DuplicateCard(),
                    if (others.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _SectionLabel(l.sectionOthers),
                      for (final g in others)
                        SizedBox(
                          height: _tileExtent,
                          child: _GroupTile(group: g),
                        ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, right, bottom),
                sliver: SliverVariedExtentList.builder(
                  key: _daysKey,
                  itemCount: entries.length,
                  itemExtentBuilder: (i, _) =>
                      entries[i] is _YearEntry ? _yearExtent : _tileExtent,
                  itemBuilder: (_, i) => switch (entries[i]) {
                    _YearEntry(:final year) => _YearDivider(year),
                    _GroupEntry(:final group) => _GroupTile(group: group),
                  },
                ),
              ),
            ],
          );
          if (!rail) return list;
          return Stack(
            children: [
              list,
              Positioned(
                right: 4,
                top: 140,
                bottom: bottom,
                width: _railWidth,
                // 스크롤바처럼: 레일 위치 = 목록 전체에서의 위치
                child: ListenableBuilder(
                  listenable: _scroll,
                  builder: (context, _) {
                    final start = _daysStart;
                    final max = _scroll.hasClients
                        ? _scroll.position.maxScrollExtent
                        : 0.0;
                    if (start == null || max <= 0) {
                      return const SizedBox.shrink();
                    }
                    return _YearRail(
                      marks: [
                        for (final (i, e) in entries.indexed)
                          if (e is _YearEntry)
                            (
                              e.year,
                              ((start + offsets[i]) / max).clamp(0.0, 1.0),
                            ),
                      ],
                      thumb: (_scroll.offset / max).clamp(0.0, 1.0),
                      current: _currentYear ?? years.first,
                      onSeek: (f) => _scroll.jumpTo(f * max),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 연도 구분선: "2025 ────"
class _YearDivider extends StatelessWidget {
  const _YearDivider(this.year);

  final int year;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Text(
            '$year',
            style: const TextStyle(
              fontSize: MehhText.caption,
              fontWeight: FontWeight.w700,
              color: MehhColors.text,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

/// 오른쪽 연도 레일 (앨범 빠른 스크롤처럼). 레일을 누르거나 위아래로 끌면
/// 그 위치로 목록이 따라 움직이고, 검은 손잡이가 지금 위치와 연도를 보여 준다.
/// 연도 글자는 목록에서 그 연도가 시작하는 위치에 놓인다.
class _YearRail extends StatelessWidget {
  const _YearRail({
    required this.marks,
    required this.thumb,
    required this.current,
    required this.onSeek,
  });

  /// (연도, 레일 위 위치 0~1)
  final List<(int, double)> marks;

  /// 지금 스크롤 위치 (0~1)
  final double thumb;
  final int current;
  final void Function(double fraction) onSeek;

  static const _thumbHeight = 22.0;
  static const _labelHeight = 16.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight;
        void seek(double dy) => onSeek((dy / h).clamp(0.0, 1.0));
        final thumbTop = thumb * (h - _thumbHeight);
        // 글자끼리, 또는 손잡이와 겹치면 그 연도 글자는 숨긴다
        final labels = <(int, double)>[];
        for (final (year, f) in marks) {
          final top = f * (h - _labelHeight);
          if (labels.isNotEmpty && top - labels.last.$2 < _labelHeight + 2) {
            continue;
          }
          if ((top - thumbTop).abs() < _thumbHeight) continue;
          labels.add((year, top));
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seek(d.localPosition.dy),
          onVerticalDragStart: (d) => seek(d.localPosition.dy),
          onVerticalDragUpdate: (d) => seek(d.localPosition.dy),
          child: Semantics(
            label: context.l.jumpToYear,
            child: CustomPaint(
              painter: const _DottedTrack(),
              child: Stack(
                children: [
                  for (final (year, top) in labels)
                    Positioned(
                      top: top,
                      left: 0,
                      right: 0,
                      height: _labelHeight,
                      child: Center(
                        child: Container(
                          color: MehhColors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            "'${year % 100}",
                            style: const TextStyle(
                              fontSize: MehhText.tiny,
                              fontWeight: FontWeight.w500,
                              color: MehhColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: thumbTop,
                    left: 0,
                    right: 0,
                    height: _thumbHeight,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        height: _thumbHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MehhColors.black,
                          borderRadius: BorderRadius.circular(MehhRadius.chip),
                        ),
                        child: Text(
                          "'${current % 100}",
                          style: const TextStyle(
                            fontSize: MehhText.tiny,
                            fontWeight: FontWeight.w700,
                            color: MehhColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 연도 레일 가운데 세로 점선
class _DottedTrack extends CustomPainter {
  const _DottedTrack();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = MehhColors.border;
    final x = size.width / 2;
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawCircle(Offset(x, y), 1, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedTrack old) => false;
}

/// "사진 N장" · 분석/위치 진행 상황
class _Subtitle extends ConsumerWidget {
  const _Subtitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(analysisProvider);
    final loc = ref.watch(libraryProvider.select((s) => s.value?.locating));

    final l = context.l;
    final parts = <String>[
      // 이번 달 보낸 용량은 아래 막대 밑에 (2026-10-24 Sophie)
      l.photoTotal(analysis.total),
      if (!analysis.done && analysis.total > 0)
        l.analyzingPercent(analysis.analyzed * 100 ~/ analysis.total)
      else if (loc != null && loc.$1 < loc.$2)
        l.locatingPercent(loc.$1 * 100 ~/ loc.$2),
    ];
    return Text(
      parts.join(' · '),
      style: const TextStyle(
        fontSize: MehhText.bodySmall,
        color: MehhColors.textMuted,
      ),
    );
  }
}

/// 검정 포인트 카드: "중복 N장 찾았어요 · 무료"
class _DuplicateCard extends ConsumerWidget {
  const _DuplicateCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(duplicatesProvider).value;
    final decisions = ref.watch(decisionsProvider).value ?? const {};
    final n = duplicatesLeft(sets, decisions);
    // 분석이 끝나야 찾을 수 있으니, 그 전에는 같은 자리에 흐린 한 줄 (UX 리뷰 2026-10-22)
    if (sets == null && !ref.watch(analysisProvider.select((a) => a.done))) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: MehhColors.surface,
            borderRadius: BorderRadius.circular(MehhRadius.card),
          ),
          child: Text(
            context.l.duplicatesPending,
            style: const TextStyle(
              fontSize: MehhText.caption,
              color: MehhColors.textMuted,
            ),
          ),
        ),
      );
    }
    if (n == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: MehhColors.black,
          borderRadius: BorderRadius.circular(MehhRadius.card),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l.duplicatesFree,
                    style: TextStyle(
                      fontSize: MehhText.label,
                      color: MehhColors.onBlackMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l.duplicatesFound(n),
                    style: const TextStyle(
                      fontSize: MehhText.lead,
                      fontWeight: FontWeight.w600,
                      color: MehhColors.white,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MehhColors.white,
                foregroundColor: MehhColors.black,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () =>
                  Navigator.of(context).push(sortRoute(SortKind.duplicates)),
              child: Text(
                context.l.review,
                style: TextStyle(
                  fontSize: MehhText.bodySmall,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTile extends ConsumerWidget {
  const _GroupTile({required this.group});

  final DayGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = group.hasCenter
        ? ref
              .watch(placeNameProvider((group.centerLat!, group.centerLng!)))
              .value
        : null;
    final entity = ref.read(photoLibraryProvider).entities[group.cover.id];
    final status = ref.watch(groupStatusProvider(group));
    final done = status == GroupStatus.done;
    final plan = ref.watch(groupPlanProvider(group));
    final decisions = ref.watch(decisionsProvider).value ?? const {};
    // 앱이 고른 추천 장수만 (직접 X는 세지 않는다). 캡처는 캡처 추천으로 센다 (시니어 리뷰 2026-10-23 S-3)
    final shots = group.kind == DayGroupKind.screenshots;
    final suggested = shots
        ? planScreenshots(
            group.photos,
            ref.watch(analysisProvider.select((a) => a.features)),
            decisions,
            now: DateTime.now(),
          ).length
        : plan.trash.length;
    final unsent = group.photos.any(
      (p) => stateOf(decisions, p.id) == DecisionState.toTrash,
    );

    final l = context.l;
    final meta = StringBuffer(l.photos(group.count));
    switch (status) {
      case GroupStatus.needsWork:
        if (suggested > 0) meta.write(' · ${l.suggestedCount(suggested)}');
      case GroupStatus.analyzing:
        meta.write(' · ${l.analyzingShort}');
      case GroupStatus.done:
        meta.write(' · ${l.allSeen}');
      case GroupStatus.nothing:
        if (shots) {
          meta.write(
            ' · ${suggested > 0 ? l.suggestedCount(suggested) : l.pickScreenshots}',
          );
        }
    }

    return InkWell(
      onTap: () => Navigator.of(context).push(
        sortRoute(
          switch (group.kind) {
            DayGroupKind.day => SortKind.day,
            DayGroupKind.singles => SortKind.singles,
            DayGroupKind.screenshots => SortKind.screenshots,
          },
          group: group,
          place: place,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MehhColors.tile)),
        ),
        child: Opacity(
          opacity: done ? 0.5 : 1,
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: PhotoThumb(
                  entity: entity,
                  radius: MehhRadius.tile,
                  size: 144,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupTitle(group, l, place: place, withYear: false),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: MehhText.body,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.toString(),
                      style: const TextStyle(
                        fontSize: MehhText.caption,
                        color: MehhColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // X를 쳐 두고 아직 안 보낸 묶음은 줄 끝 작은 점 (2026-10-22 Sophie R4-A)
              if (unsent)
                Semantics(
                  label: l.unsentDot,
                  child: Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsetsDirectional.only(end: 6),
                    decoration: const BoxDecoration(
                      color: MehhColors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              const Icon(Icons.chevron_right, size: 18, color: MehhColors.icon),
            ],
          ),
        ),
      ),
    );
  }
}

class _LimitedBanner extends StatelessWidget {
  const _LimitedBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: MehhColors.surface,
        borderRadius: BorderRadius.circular(MehhRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l.limitedAccess,
              style: TextStyle(
                fontSize: MehhText.caption,
                color: MehhColors.text,
                height: 1.5,
              ),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: MehhColors.text,
              minimumSize: const Size(44, 44),
            ),
            child: Text(context.l.choosePhotos),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.action});

  final String text;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final a = action;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: MehhText.body,
              color: MehhColors.textMuted,
            ),
          ),
          if (a != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: a.$2, child: Text(a.$1)),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: MehhText.label,
          fontWeight: FontWeight.w500,
          color: MehhColors.textMuted,
        ),
      ),
    );
  }
}
