import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/device.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../theme.dart';
import 'widgets.dart';

/// 용량 막대 (2026-10-24 Sophie). 막대 전체 = 사진 전체 용량 + 이번 달 휴지통으로 보낸 용량.
/// - 검정: 사진이 지금 차지한 용량 (비울 수 있는 것 빼고)
/// - 진한 회색: 비울 수 있는 용량 (선택한 것 + 앱 추천)
/// - 연한 회색: 이번 달 휴지통으로 보낸 용량. 지울수록 늘어난다
/// 아래 한 줄이 색마다 무엇인지 알려 준다. 홈과 정리 화면의 같은 높이에 둔다([MehhHeader]).
class FreedBar extends ConsumerWidget {
  const FreedBar({super.key, this.extra = const []});

  /// 앱 추천·선택 말고도 지금 화면에서 X로 보이는 사진 (정리 화면의 "처음부터 X")
  final List<String> extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(photoBytesProvider).value ?? 0;
    final freed = ref.watch(freedThisMonthProvider).value ?? 0;
    final ids = {...ref.watch(cleanableIdsProvider), ...extra}.toList()..sort();
    final cleanable = ref.watch(idsBytesProvider(ids.join(','))).value ?? 0;
    if (photos == 0) return const SizedBox.shrink();
    final can = cleanable.clamp(0, photos);
    final l = context.l;
    return Padding(
      key: const ValueKey('freedBar'),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(MehhRadius.strip),
            child: SizedBox(
              height: 4,
              child: LayoutBuilder(
                builder: (context, c) {
                  final total = (photos + freed).toDouble();
                  // 아주 작아도 0이 아니면 보이게 최소 폭
                  double w(int part) => part == 0
                      ? 0
                      : (c.maxWidth * part / total).clamp(3.0, c.maxWidth);
                  final wCan = w(can);
                  final wFreed = w(freed);
                  // 검정 바탕 위에 오른쪽부터 연한 회색(보낸 것), 그 왼쪽에 진한 회색(비울 수 있는 것)
                  return Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: MehhColors.black),
                      ),
                      _Part(
                        right: wFreed,
                        width: wCan,
                        color: MehhColors.textMuted,
                      ),
                      _Part(right: 0, width: wFreed, color: MehhColors.border),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Legend(MehhColors.black, l.barPhotos(formatBytes(photos))),
              if (can > 0)
                _Legend(MehhColors.textMuted, l.barCleanable(formatBytes(can))),
              if (freed > 0)
                _Legend(MehhColors.border, l.barSent(formatBytes(freed))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({required this.right, required this.width, required this.color});
  final double right;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedPositioned(
    duration: freedBarAnimation,
    curve: Curves.easeOutCubic,
    top: 0,
    bottom: 0,
    right: right,
    width: width,
    child: ColoredBox(color: color),
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.text);
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(
          fontSize: MehhText.caption,
          color: MehhColors.textMuted,
        ),
      ),
    ],
  );
}

/// 오른쪽 위 휴지통: 갤러리 앱의 휴지통을 연다 (홈·정리 화면 같은 자리)
class GalleryTrashButton extends ConsumerWidget {
  const GalleryTrashButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    return IconButton(
      tooltip: l.openTrash,
      onPressed: () async {
        final r = await ref.read(deviceProvider).openTrash();
        if (!context.mounted) return;
        switch (r) {
          case TrashOpen.trash:
            break;
          case TrashOpen.gallery:
            showNote(context, l.trashOpenedGallery);
          case TrashOpen.none:
            showNote(context, l.trashNoGallery);
        }
      },
      icon: const Icon(Icons.delete_outline, size: 22, color: MehhColors.icon),
    );
  }
}

/// 맨 위 줄(로고·돌아가기 / 휴지통·설정)과 제목 칸의 높이를 홈과 정리 화면이 같이 써서
/// 막대가 같은 높이에 오게 한다 (2026-10-24 Sophie)
abstract final class MehhHeader {
  /// 맨 위 줄 높이
  static const topBar = 64.0;

  /// 맨 위 줄 아래 ~ 막대 위까지 (제목·작은 줄). 내용은 아래에 붙는다
  static const title = 112.0;

  /// 맨 위 줄
  static Widget top({
    required Widget leading,
    required List<Widget> trailing,
  }) => SizedBox(
    height: topBar,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        leading,
        Row(mainAxisSize: MainAxisSize.min, children: trailing),
      ],
    ),
  );

  /// 제목 칸: 최소 [title] 높이, 내용은 아래(막대 쪽)에 붙인다. 큰 글씨면 늘어난다
  static Widget titleBox(List<Widget> children) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: title),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    ),
  );
}
