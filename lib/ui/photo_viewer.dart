import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../providers.dart';
import '../theme.dart';

/// 사진 크게 보기. 열어본 기록을 남긴다 (보류함 유예기간용).
void openPhoto(BuildContext context, String id, {List<Widget>? actions}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PhotoViewer(id: id, actions: actions),
    ),
  );
}

class PhotoViewer extends ConsumerStatefulWidget {
  const PhotoViewer({super.key, required this.id, this.actions});

  final String id;
  final List<Widget>? actions;

  @override
  ConsumerState<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<PhotoViewer> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(viewsProvider.notifier).record(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    final e = ref.read(photoLibraryProvider).entities[widget.id];
    final actions = widget.actions;
    return Scaffold(
      backgroundColor: MehhColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: MehhColors.text),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LargePhoto(entity: e),
              ),
            ),
            if (actions != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// 화면에 맞춰 크게 보여주는 사진 (회색 바탕, 모서리 둥글게)
class LargePhoto extends StatelessWidget {
  const LargePhoto({super.key, required this.entity});

  final AssetEntity? entity;

  @override
  Widget build(BuildContext context) {
    final e = entity;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
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
