import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../l10n/l10n.dart';
import '../theme.dart';

/// 사진 썸네일. 로딩 중에는 회색 칸.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.entity,
    this.radius = MehhRadius.thumb,
    this.size = 200,
  });

  final AssetEntity? entity;
  final double radius;
  final int size;

  @override
  Widget build(BuildContext context) {
    final e = entity;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: MehhColors.tile,
        child: e == null
            ? const Center(
                child: FractionallySizedBox(
                  widthFactor: 0.36,
                  child: FittedBox(
                    child: Icon(Icons.image_outlined, color: MehhColors.icon),
                  ),
                ),
              )
            : Image(
                image: AssetEntityImageProvider(
                  e,
                  isOriginal: false,
                  thumbnailSize: ThumbnailSize.square(size),
                ),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.expand(),
              ),
      ),
    );
  }
}

/// 홈 헤더 로고: 염소만. 손글씨 mehh...는 크게 보이는 온보딩에서만 쓴다.
class MehhLogo extends StatelessWidget {
  const MehhLogo({super.key, this.height = 38});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/mehh-goat.png',
      width: height * 34 / 38,
      height: height,
      semanticLabel: 'Mehh',
    );
  }
}

/// 검정 작은 배지 ("베스트", "남김")
class MehhBadge extends StatelessWidget {
  const MehhBadge(this.text, {super.key, this.inverted = false});

  final String text;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    // 사진 칸은 크기가 정해져 있어서 큰 글씨 설정에서도 배지가 사진을 덮지 않게 묶는다
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: inverted ? MehhColors.white : MehhColors.black,
          borderRadius: BorderRadius.circular(MehhRadius.badge),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: MehhText.micro,
            fontWeight: FontWeight.w500,
            color: inverted ? MehhColors.text : MehhColors.white,
          ),
        ),
      ),
    );
  }
}

/// 정리 표시 (검정 동그라미 X)
class XMark extends StatelessWidget {
  const XMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: MehhColors.black,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.close, size: 10, color: MehhColors.white),
    );
  }
}

/// 사진 모서리 X 버튼: 켜지면 정리, 꺼지면 킵. 누르기 쉽게 영역은 크게.
class XToggle extends StatelessWidget {
  const XToggle({super.key, required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: on ? context.l.pileCancel : context.l.markForRemoval,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: on
                  ? const XMark()
                  : Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: MehhColors.white.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: MehhColors.icon),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 2.3GB, 840MB
String formatBytes(int bytes) {
  const gb = 1024 * 1024 * 1024, mb = 1024 * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)}GB';
  if (bytes >= mb) return '${(bytes / mb).round()}MB';
  return '${(bytes / 1024).ceil()}KB';
}

/// 한 줄 알림 (화면 아래)
void showNote(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: text.contains(coinMark)
            ? CoinText(text, style: const TextStyle(color: MehhColors.white))
            : Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: MehhColors.black,
        // 긴 안내는 읽을 시간을 더 준다 (2~8초)
        duration: Duration(seconds: (2 + text.length ~/ 25).clamp(2, 8)),
      ),
    );
}

String formatCount(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 화면 머리의 돌아가기 버튼 (모든 화면 같은 모양·위치, 오른쪽→왼쪽 언어도 시작 쪽)
class MehhBackButton extends StatelessWidget {
  const MehhBackButton({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: IconButton(
      tooltip: context.l.back,
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.chevron_left, color: MehhColors.text),
    ),
  );
}

/// 확인 창 (모든 화면 같은 모양). [yes]를 누르면 true.
Future<bool> askMehh(
  BuildContext context, {
  required String title,
  String? body,
  required String no,
  required String yes,
  Widget? titleLeading,
  Widget? titleTrailing,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MehhColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MehhRadius.card),
        ),
        title: Row(
          children: [
            if (titleLeading != null) ...[
              titleLeading,
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: MehhText.heading,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?titleTrailing,
          ],
        ),
        content: body == null
            ? null
            : Text(
                body,
                style: const TextStyle(
                  fontSize: MehhText.bodySmall,
                  height: 1.5,
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            style: TextButton.styleFrom(foregroundColor: MehhColors.textMuted),
            child: Text(no),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: TextButton.styleFrom(foregroundColor: MehhColors.black),
            child: Text(
              yes,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ) ==
    true;

/// 코인: Sophie가 그린 동그라미 속 뿔 (2026-10-24, assets/coin.png). 그날의 묶음 추천을 하나 여는 데
/// 1개, 매달 몇 개 생긴다. 이름 대신 이 그림으로 부른다 ("[코인] 1개로 열까요?").
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/coin.png',
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
  );
}

/// 코인 아이콘 + 개수 ("[코인] 3")
class CoinCount extends StatelessWidget {
  const CoinCount(this.count, {super.key, this.size = 16});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l.coinCount(count),
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoinIcon(size: size),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: MehhText.caption,
            fontWeight: FontWeight.w600,
            color: MehhColors.black,
          ),
        ),
      ],
    ),
  );
}

/// 묶음 이름 바꾸기 (2026-10-24 Sophie). 입력 칸 오른쪽 [원래 이름으로]는 기본 이름을 다시 넣는다.
/// 반환: 새 이름, 기본 이름으로 되돌리면 빈 문자열, 취소면 null
Future<String?> askGroupName(
  BuildContext context, {
  required String current,
  required String original,
}) {
  final c = TextEditingController(text: current);
  final l = context.l;
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: MehhColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MehhRadius.card),
      ),
      title: Text(
        l.renameTitle,
        style: const TextStyle(
          fontSize: MehhText.heading,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.of(ctx).pop(v == original ? '' : v),
        decoration: InputDecoration(
          counterText: '',
          suffixIcon: IconButton(
            tooltip: l.renameReset,
            icon: const Icon(Icons.restart_alt, color: MehhColors.icon),
            onPressed: () => c.text = original,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          style: TextButton.styleFrom(foregroundColor: MehhColors.textMuted),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(ctx).pop(c.text == original ? '' : c.text),
          style: TextButton.styleFrom(foregroundColor: MehhColors.black),
          child: Text(
            l.save,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// 문구 속 코인 자리 표시. 화면에는 글자 "코인" 대신 코인 그림이 들어간다 (2026-10-24 Sophie)
const coinMark = '◉';

/// [text]의 [coinMark]를 코인 그림으로 바꿔 보여 준다
class CoinText extends StatelessWidget {
  const CoinText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final size = (style?.fontSize ?? MehhText.body) * 1.25;
    final parts = text.split(coinMark);
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: CoinIcon(size: size),
              ),
            TextSpan(text: parts[i]),
          ],
        ],
      ),
      style: style,
      semanticsLabel: text.replaceAll(coinMark, context.l.coinWord),
    );
  }
}
