import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../l10n/l10n.dart';
import '../providers.dart';
import '../theme.dart';

/// 사진 크게 보기. 열어본 기록을 남긴다 (취향 학습용).
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
                tooltip: context.l.close,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: MehhColors.text),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ZoomablePhoto(entity: e),
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

/// 두 손가락으로 확대할 수 있는 큰 사진. 확대 여부를 [onZoomChanged]로 알린다
/// (확대 중에는 넘기기 화면이 좌우로 넘어가지 않게).
class ZoomablePhoto extends StatefulWidget {
  const ZoomablePhoto({super.key, required this.entity, this.onZoomChanged});

  final AssetEntity? entity;
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<ZoomablePhoto> {
  final _controller = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update() {
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged?.call(zoomed);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(MehhRadius.photo),
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 4,
        panEnabled: _zoomed,
        onInteractionUpdate: (_) => _update(),
        onInteractionEnd: (_) => _update(),
        child: LargePhoto(entity: widget.entity),
      ),
    );
  }
}
