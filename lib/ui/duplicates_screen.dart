import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photo_manager/photo_manager.dart';

import '../logic/duplicates.dart';
import '../providers.dart';
import '../theme.dart';
import 'widgets.dart';

/// 완전 중복: 묶음마다 하나만 남기고 나머지를 한 번에 휴지통으로 (무료).
class DuplicatesScreen extends ConsumerStatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  ConsumerState<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends ConsumerState<DuplicatesScreen> {
  bool _busy = false;

  Future<void> _clean(List<DuplicateSet> sets) async {
    setState(() => _busy = true);
    final ids = [for (final s in sets) ...s.remove.map((p) => p.id)];
    final n = await ref.read(cleanerProvider).trash(ids);
    if (!mounted) return;
    setState(() => _busy = false);
    if (n > 0) {
      showNote(context, '${formatCount(n)}장을 휴지통으로 보냈어요');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sets = ref.watch(duplicatesProvider).value ?? const [];
    final entities = ref.read(photoLibraryProvider).entities;
    final n = sets.fold<int>(0, (n, s) => n + s.remove.length);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
              child: IconButton(
                tooltip: '홈으로',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.chevron_left, color: MehhColors.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '똑같은 사진 ${formatCount(n)}장',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '가장 큰 사진 하나만 남기고 나머지를 휴지통으로 보낼게요. 30일 안에 되살릴 수 있어요.',
                    style: TextStyle(fontSize: 14, color: MehhColors.textMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                itemCount: sets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final s = sets[i];
                  return SizedBox(
                    height: 80,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _Tile(entity: entities[s.keep.id], keep: true),
                        for (final p in s.remove)
                          _Tile(entity: entities[p.id], keep: false),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy || n == 0 ? null : () => _clean(sets),
                  child: Text(
                    '${formatCount(n)}장 휴지통으로',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.entity, required this.keep});

  final AssetEntity? entity;
  final bool keep;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        width: 80,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: keep ? 1 : 0.45,
              child: PhotoThumb(entity: entity),
            ),
            Positioned(
              left: 4,
              bottom: 4,
              child: keep ? const MehhBadge('남김') : const XMark(),
            ),
          ],
        ),
      ),
    );
  }
}
