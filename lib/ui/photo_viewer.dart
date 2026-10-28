import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../theme.dart';

/// 화면에 맞춰 크게 보여주는 사진 (회색 바탕, 모서리 둥글게)
class LargePhoto extends StatelessWidget {
  const LargePhoto({super.key, required this.entity});

  final AssetEntity? entity;

  @override
  Widget build(BuildContext context) {
    final e = entity;
    return ClipRRect(
      borderRadius: BorderRadius.circular(MehhRadius.photo),
      child: ColoredBox(
        color: MehhColors.tile,
        child: e == null
            ? const Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 88,
                  color: MehhColors.icon,
                ),
              )
            : Image(
                image: AssetEntityImageProvider(
                  e,
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize(1440, 1440),
                ),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
              ),
      ),
    );
  }
}
