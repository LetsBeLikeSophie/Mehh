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

/// 염소 + Mehh 로고
class MehhLogo extends StatelessWidget {
  const MehhLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/mehh-goat.png', width: 30, height: 34),
        const SizedBox(width: 6),
        const Text(
          'Mehh',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
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
