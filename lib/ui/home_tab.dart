import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../logic/format.dart';
import '../models/day_group.dart';
import '../models/decision.dart';
import '../providers.dart';
import '../theme.dart';
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

  void _jumpToYear(int year) {
    final start = _daysStart;
    final i = _entries.indexWhere((e) => e is _YearEntry && e.year == year);
    if (start == null || i < 0) return;
    _scroll.jumpTo(
      (start + _offsets[i]).clamp(0.0, _scroll.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final limited = ref.watch(permissionProvider) == PermissionState.limited;

    return SafeArea(
      bottom: false,
      child: library.when(
        loading: () => const _Message('사진을 묶는 중이에요'),
        error: (e, _) => _Message(
          '사진을 불러오지 못했어요',
          action: ('다시 시도', () => ref.read(libraryProvider.notifier).reload()),
        ),
        data: (state) {
          if (state.groups.isEmpty) return const _Message('정리할 사진이 없어요');
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
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 16, right, 0),
                sliver: SliverList.list(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const MehhLogo(),
                        IconButton(
                          tooltip: '설정',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                          icon: const Icon(
                            Icons.settings_outlined,
                            size: 22,
                            color: MehhColors.icon,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      left == 0
                          ? '지금은\n정리할 묶음이 없어요'
                          : '정리할 묶음\n${formatCount(left)}개 남았어요',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _Subtitle(),
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
                      const _SectionLabel('따로 보기'),
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
                child: _YearRail(
                  years: years,
                  current: _currentYear ?? years.first,
                  onYear: _jumpToYear,
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
              fontSize: 13,
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

/// 오른쪽 연도 레일: 누르거나 위아래로 끌면 그 연도로 이동 (앨범 빠른 스크롤처럼)
class _YearRail extends StatelessWidget {
  const _YearRail({
    required this.years,
    required this.current,
    required this.onYear,
  });

  final List<int> years;
  final int current;
  final void Function(int year) onYear;

  void _pick(double dy, double height) {
    final i = (dy / height * years.length).floor().clamp(0, years.length - 1);
    onYear(years[i]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _pick(d.localPosition.dy, box.maxHeight),
        onVerticalDragUpdate: (d) => _pick(d.localPosition.dy, box.maxHeight),
        child: Semantics(
          label: '연도 이동',
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final y in years)
                Text(
                  "'${y % 100}",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: y == current
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: y == current ? MehhColors.black : MehhColors.icon,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "이번 달 2.3GB 비웠어요" · 분석/위치 진행 상황
class _Subtitle extends ConsumerWidget {
  const _Subtitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freed = ref.watch(freedThisMonthProvider).value ?? 0;
    final analysis = ref.watch(analysisProvider);
    final loc = ref.watch(libraryProvider.select((s) => s.value?.locating));

    final parts = <String>[
      if (freed > 0) '이번 달 ${formatBytes(freed)} 비웠어요',
      if (freed == 0) '사진 ${formatCount(analysis.total)}장',
      if (!analysis.done && analysis.total > 0)
        '사진 살펴보는 중 ${analysis.analyzed * 100 ~/ analysis.total}%'
      else if (loc != null && loc.$1 < loc.$2)
        '장소 확인 중 ${loc.$1 * 100 ~/ loc.$2}%',
    ];
    return Text(
      parts.join(' · '),
      style: const TextStyle(fontSize: 14, color: MehhColors.textMuted),
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
                  const Text(
                    '똑같은 사진 · 무료',
                    style: TextStyle(fontSize: 12, color: Color(0xFFB4B4B0)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '중복 ${formatCount(n)}장 찾았어요',
                    style: const TextStyle(
                      fontSize: 16,
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
              child: const Text(
                '살펴보기',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
    final decisions = ref.watch(decisionsProvider).value ?? const {};
    final status = ref.watch(groupStatusProvider(group));
    final done = status == GroupStatus.done;
    final plan = ref.watch(groupPlanProvider(group));
    final pile =
        plan.trash.length +
        group.photos
            .where((p) => stateOf(decisions, p.id) == DecisionState.toTrash)
            .length;

    final meta = StringBuffer('${formatCount(group.count)}장');
    switch (status) {
      case GroupStatus.needsWork:
        meta.write(' · 정리 추천 ${formatCount(pile)}장');
      case GroupStatus.analyzing:
        meta.write(' · 살펴보는 중');
      case GroupStatus.done:
        meta.write(' · 다 봤어요');
      case GroupStatus.nothing:
        if (group.kind == DayGroupKind.screenshots) {
          meta.write(' · 지울 캡처를 골라 보세요');
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
                child: PhotoThumb(entity: entity, radius: 8, size: 144),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupTitle(group, place: place),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: MehhColors.textMuted,
                      ),
                    ),
                  ],
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
          const Expanded(
            child: Text(
              '일부 사진만 허용했어요.\n전체를 허용하면 더 많이 찾을 수 있어요.',
              style: TextStyle(
                fontSize: 13,
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
            child: const Text('사진 고르기'),
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
            style: const TextStyle(fontSize: 15, color: MehhColors.textMuted),
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
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: MehhColors.textMuted,
        ),
      ),
    );
  }
}
