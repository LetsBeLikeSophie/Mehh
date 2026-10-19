import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

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
  const MehhLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/mehh-goat.png',
      width: 34,
      height: 38,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: inverted ? MehhColors.white : MehhColors.black,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: inverted ? MehhColors.text : MehhColors.white,
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
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: MehhColors.black,
        duration: const Duration(seconds: 2),
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
