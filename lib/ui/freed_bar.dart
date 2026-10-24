import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../theme.dart';
import 'pro_sheet.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// 용량 막대 (2026-10-24 Sophie). 홈과 정리 화면이 같은 막대·같은 뜻을 쓴다.
/// 막대 전체 = 사진 전체 용량 + 이번 달 휴지통으로 보낸 용량. 왼쪽부터
/// - 검정: 사진 (남는 것)
/// - 연한 코랄: 추천 정리 (앱 추천 + 선택해 둔 것)
/// - 코랄: 정리 화면에서만, 이 묶음에서 지금 선택한 것 — 선택하면 연한 코랄에서 코랄로 옮겨 간다
/// - 회색: 휴지통 (이번 달 보낸 것)
/// 아래 한 줄은 글자 색이 칸 색과 같고, 길면 줄을 바꾸지 않고 글자를 줄인다.
class FreedBar extends ConsumerWidget {
  const FreedBar({super.key, this.selected});

  /// 정리 화면: 이 묶음에서 지금 선택한(X) 사진 → 코랄 칸. 홈은 null: 선택 칸 없이
  /// 선택한 것도 추천 정리(연한 코랄)에 넣는다 (2026-10-24 Sophie)
  final List<String>? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(photoBytesProvider).value ?? 0;
    final freed = ref.watch(freedThisMonthProvider).value ?? 0;
    final selectedIds = {...?selected};
    final pickIds = {
      ...ref.watch(cleanableIdsProvider),
      ...ref.watch(selectedIdsProvider),
    }.where((id) => !selectedIds.contains(id));
    final selectedBytes =
        ref
            .watch(idsBytesProvider((selectedIds.toList()..sort()).join(',')))
            .value ??
        0;
    final picks =
        ref
            .watch(idsBytesProvider((pickIds.toList()..sort()).join(',')))
            .value ??
        0;
    if (photos == 0) return const SizedBox.shrink();
    final sel = selectedBytes.clamp(0, photos);
    final rec = picks.clamp(0, photos - sel);
    final l = context.l;
    const small = TextStyle(fontSize: MehhText.label);
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
                  final wFreed = w(freed);
                  final wSel = w(sel);
                  final wRec = w(rec);
                  // 검정 바탕 위에 오른쪽부터 휴지통 · 선택 · 추천 정리
                  return Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: MehhColors.black),
                      ),
                      _Part(
                        right: wFreed + wSel,
                        width: wRec,
                        color: MehhColors.accentSoft,
                      ),
                      _Part(
                        right: wFreed,
                        width: wSel,
                        color: MehhColors.accent,
                      ),
                      _Part(right: 0, width: wFreed, color: MehhColors.icon),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text.rich(
                    TextSpan(
                      style: small,
                      children: [
                        TextSpan(
                          text: l.barPhotos(formatBytes(photos)),
                          style: const TextStyle(color: MehhColors.black),
                        ),
                        if (rec > 0) ...[
                          const TextSpan(text: '  ·  '),
                          TextSpan(
                            text: l.barRecommended(formatBytes(rec)),
                            style: const TextStyle(
                              color: MehhColors.accentSoftText,
                            ),
                          ),
                        ],
                        if (sel > 0) ...[
                          const TextSpan(text: '  ·  '),
                          TextSpan(
                            text: l.barSelected(formatBytes(sel)),
                            style: const TextStyle(color: MehhColors.accent),
                          ),
                        ],
                      ],
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
              if (freed > 0) ...[
                const SizedBox(width: 8),
                Text(
                  l.barSent(formatBytes(freed)),
                  style: small.copyWith(color: MehhColors.textMuted),
                ),
              ],
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

/// 오른쪽 위 갤러리 아이콘: 갤러리 앱을 연다 (모든 화면 같은 자리).
/// 휴지통을 바로 열 공통 방법이 없어 갤러리 모양으로 둔다 (2026-10-24 Sophie)
class GalleryButton extends ConsumerWidget {
  const GalleryButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    return MehhHeader.icon(
      tooltip: l.openGallery,
      asset: 'assets/gallery.png',
      onPressed: () async {
        final ok = await ref.read(deviceProvider).openGallery();
        if (!ok && context.mounted) showNote(context, l.noGallery);
      },
    );
  }
}

/// 맨 위 오른쪽: [코인 N] · 갤러리 · 설정(맨 오른쪽). 홈·정리·크게 보기 모든 화면 같은 자리 (2026-10-24 Sophie)
class MehhTopActions extends StatelessWidget {
  const MehhTopActions({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const ProChip(),
      const GalleryButton(),
      MehhHeader.icon(
        tooltip: context.l.settings,
        asset: 'assets/settings.png',
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
      ),
    ],
  );
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

  /// 맨 위 줄 아이콘 버튼: 서로 가깝게 (2026-10-24 Sophie: 아이콘 사이가 너무 멀다)
  /// [asset]: Sophie가 그린 손그림 아이콘 (코인과 같은 결, 2026-10-24)
  static Widget icon({
    required String tooltip,
    required String asset,
    required VoidCallback onPressed,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    icon: Image.asset(
      asset,
      width: 22,
      height: 22,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
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
