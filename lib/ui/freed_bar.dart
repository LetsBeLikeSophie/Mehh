import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../theme.dart';
import 'widgets.dart';

/// 얇은 가로 막대: 검은 부분 = 이번 달 휴지통으로 보낸 용량, 회색 부분 = 선택했지만 아직 안 보낸 용량.
/// 바로 아래 한 줄이 막대를 설명한다 ("이번 달 휴지통으로 70MB 보냈어요 · 선택 15MB").
/// 홈과 정리 화면 제목 아래 같은 자리에 둔다. 선택·보내기에 따라 바로 바뀐다 (2026-10-24 Sophie)
class FreedBar extends ConsumerWidget {
  const FreedBar({super.key, this.extra = const []});

  /// 결정으로 저장되지 않았지만 X로 보이는 사진 (정리 화면의 "처음부터 X")
  final List<String> extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freed = ref.watch(freedThisMonthProvider).value ?? 0;
    final selected =
        (ref.watch(markedBytesProvider).value ?? 0) +
        (ref
                .watch(idsBytesProvider((extra.toList()..sort()).join(',')))
                .value ??
            0);
    if (freed + selected == 0) return const SizedBox.shrink();
    final l = context.l;
    final parts = [
      if (freed > 0) l.freedThisMonth(formatBytes(freed)),
      if (selected > 0) l.selectedSize(formatBytes(selected)),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: freed / (freed + selected)),
            duration: freedBarAnimation,
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(MehhRadius.strip),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 4,
                color: MehhColors.black,
                backgroundColor: MehhColors.border,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            parts.join(' · '),
            style: const TextStyle(
              fontSize: MehhText.bodySmall,
              color: MehhColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
