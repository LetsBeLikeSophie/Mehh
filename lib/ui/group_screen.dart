import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/format.dart';
import '../models/day_group.dart';
import '../providers.dart';
import '../theme.dart';
import 'widgets.dart';

/// 묶음 안. 1단계는 추천 없이 그리드만.
class GroupScreen extends ConsumerWidget {
  const GroupScreen({super.key, required this.group, this.place});

  final DayGroup group;
  final String? place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entities = ref.read(photoLibraryProvider).entities;
    // 최신 사진이 위로
    final photos = group.photos.reversed.toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 16),
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
                          groupTitle(group, place: place),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatCount(group.count)}장 · ${groupTimeRange(group)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: MehhColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: photos.length,
                itemBuilder: (_, i) =>
                    PhotoThumb(entity: entities[photos[i].id]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
