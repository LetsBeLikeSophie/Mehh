import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../logic/format.dart';
import '../models/day_group.dart';
import '../providers.dart';
import '../theme.dart';
import 'group_screen.dart';
import 'widgets.dart';

/// 홈: 그날의 묶음 목록 (최신순).
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
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverList.list(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: MehhLogo(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '정리할 날\n${formatCount(state.dayGroupCount)}개 남았어요',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _subtitle(state),
                      style: const TextStyle(
                        fontSize: 14,
                        color: MehhColors.textMuted,
                      ),
                    ),
                    if (limited) ...[
                      const SizedBox(height: 20),
                      _LimitedBanner(
                        onTap: () async {
                          await ref.read(photoLibraryProvider).presentLimited();
                          ref.read(libraryProvider.notifier).reload();
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        '그날의 묶음',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: MehhColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.builder(
                  itemCount: state.groups.length,
                  itemBuilder: (_, i) => _GroupTile(group: state.groups[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _subtitle(LibraryState s) {
    final total = s.groups.fold<int>(0, (n, g) => n + g.count);
    final base = '사진 ${formatCount(total)}장';
    final loc = s.locating;
    if (loc == null || loc.$1 >= loc.$2) return base;
    return '$base · 장소 확인 중 ${loc.$1 * 100 ~/ loc.$2}%';
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

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupScreen(group: group, place: place),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MehhColors.tile)),
        ),
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
                    '${formatCount(group.count)}장',
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
