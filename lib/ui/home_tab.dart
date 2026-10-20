import 'package:flutter/material.dart';
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

/// 홈: 중복 카드 + 그날의 묶음 목록 (최신순).
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          final decisions = ref.watch(decisionsProvider).value ?? const {};
          final days = [
            for (final g in state.groups)
              if (g.kind == DayGroupKind.day) g,
          ];
          final others = [
            for (final g in state.groups)
              if (g.kind != DayGroupKind.day) g,
          ];
          final left = days.where((g) => !groupDone(g, decisions)).length;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                    const SizedBox(height: 24),
                    if (days.isNotEmpty) const _SectionLabel('그날의 묶음'),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: days.length,
                  itemBuilder: (_, i) => _GroupTile(group: days[i]),
                ),
              ),
              if (others.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  sliver: SliverList.list(
                    children: [
                      const _SectionLabel('따로 보기'),
                      for (final g in others) _GroupTile(group: g),
                    ],
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
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
    final done = groupDone(group, decisions);
    final plan = ref.watch(groupPlanProvider(group));

    final meta = StringBuffer('${formatCount(group.count)}장');
    if (group.kind == DayGroupKind.screenshots) {
      meta.write(' · 다른 앱으로 보내고 정리');
    } else if (group.kind == DayGroupKind.singles && !done) {
      final left = group.photos
          .where((p) => stateOf(decisions, p.id) == DecisionState.undecided)
          .length;
      meta.write(' 중 ${formatCount(left)}장 남음');
    } else if (done) {
      meta.write(' · 다 봤어요');
    } else if (plan.analyzed < group.count) {
      meta.write(' · 살펴보는 중');
    } else if (plan.trash.isNotEmpty) {
      meta.write(' · 정리 추천 ${formatCount(plan.trash.length)}장');
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
