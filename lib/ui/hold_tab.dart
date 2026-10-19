import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/hold.dart';
import '../models/decision.dart';
import '../models/photo_meta.dart';
import '../providers.dart';
import '../theme.dart';
import 'photo_viewer.dart';
import 'widgets.dart';

class HeldPhoto {
  const HeldPhoto(this.photo, this.daysLeft);
  final PhotoMeta photo;
  final int daysLeft;
}

/// 보류 중인 사진 (남은 날 짧은 순)
final heldProvider = Provider<List<HeldPhoto>>((ref) {
  final photos =
      ref.watch(libraryProvider.select((s) => s.value?.photos)) ?? const [];
  final decisions = ref.watch(decisionsProvider).value ?? const {};
  final views = ref.watch(viewsProvider).value ?? const {};
  final now = DateTime.now();
  final list = [
    for (final p in photos)
      if (decisions[p.id] case final d? when d.state == DecisionState.hold)
        HeldPhoto(p, holdDaysLeft(holdDueAt(d, views[p.id]), now)),
  ]..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
  return list;
});

/// 보류함 (SPEC 5-4, 6-6)
class HoldTab extends ConsumerWidget {
  const HoldTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final held = ref.watch(heldProvider);
    final due = held.where((h) => h.daysLeft <= 0).toList();
    final waiting = held.where((h) => h.daysLeft > 0).toList();
    final entities = ref.read(photoLibraryProvider).entities;

    Future<void> keep(Iterable<String> ids) =>
        ref.read(decisionsProvider.notifier).set(ids, DecisionState.keep);
    Future<int> trash(Iterable<String> ids) =>
        ref.read(cleanerProvider).trash(ids);

    void open(String id) => openPhoto(
      context,
      id,
      actions: [
        OutlinedButton(
          onPressed: () async {
            await keep([id]);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('남기기'),
        ),
        FilledButton(
          onPressed: () async {
            final n = await trash([id]);
            if (n > 0 && context.mounted) Navigator.of(context).pop();
          },
          child: const Text('정리'),
        ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            sliver: SliverList.list(
              children: [
                const Text(
                  '보류함',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '30일 동안 한 번도 안 열어본 사진은 정리할지 물어볼게요.',
                  style: TextStyle(
                    fontSize: 14,
                    color: MehhColors.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                if (held.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        '보류한 사진이 없어요.\n하나씩 보기에서 위로 올리면 여기로 와요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: MehhColors.textMuted,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                if (due.isNotEmpty) ...[
                  _DueCard(
                    due: due,
                    onKeep: () => keep(due.map((h) => h.photo.id)),
                    onTrash: () async {
                      final n = await trash(due.map((h) => h.photo.id));
                      if (n > 0 && context.mounted) {
                        showNote(context, '${formatCount(n)}장을 휴지통으로 보냈어요');
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                ],
                if (waiting.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '보류 중 ${formatCount(waiting.length)}장',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: MehhColors.textMuted,
                          ),
                        ),
                        Text(
                          '가장 빠른 결정 D-${waiting.first.daysLeft}',
                          style: const TextStyle(
                            fontSize: 12,
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: waiting.length,
              itemBuilder: (_, i) {
                final h = waiting[i];
                return GestureDetector(
                  onTap: () => open(h.photo.id),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PhotoThumb(entity: entities[h.photo.id]),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: MehhBadge('D-${h.daysLeft}', inverted: true),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// "8장, 30일 동안 한 번도 안 보셨어요" + [계속 둘래요] / [이제 정리]
class _DueCard extends ConsumerWidget {
  const _DueCard({
    required this.due,
    required this.onKeep,
    required this.onTrash,
  });

  final List<HeldPhoto> due;
  final VoidCallback onKeep;
  final VoidCallback onTrash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entities = ref.read(photoLibraryProvider).entities;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MehhColors.surface,
        borderRadius: BorderRadius.circular(MehhRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${formatCount(due.length)}장, 30일 동안\n한 번도 안 보셨어요',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: MehhColors.black,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '결정할 때',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MehhColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final h in due.take(8))
                PhotoThumb(entity: entities[h.photo.id]),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onKeep,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: MehhColors.white,
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Text('계속 둘래요'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onTrash,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Text('이제 정리'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
