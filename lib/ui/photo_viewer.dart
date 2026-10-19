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

/// 묶음 안 사진 크게 보기: 좌우로 넘기고, 정리 예정인지 크게 보여준다.
/// X는 [onToggle]로 묶음 화면과 같은 상태를 바꾼다.
class PhotoPager extends ConsumerStatefulWidget {
  const PhotoPager({
    super.key,
    required this.ids,
    required this.initial,
    required this.isMarked,
    required this.onToggle,
  });

  final List<String> ids;
  final int initial;
  final bool Function(String id) isMarked;
  final void Function(String id) onToggle;

  @override
  ConsumerState<PhotoPager> createState() => _PhotoPagerState();
}

class _PhotoPagerState extends ConsumerState<PhotoPager> {
  late final PageController _page = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void initState() {
    super.initState();
    _record(_index);
  }

  void _record(int i) => Future.microtask(
    () => ref.read(viewsProvider.notifier).record(widget.ids[i]),
  );

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entities = ref.read(photoLibraryProvider).entities;
    final id = widget.ids[_index];
    final marked = widget.isMarked(id);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: MehhColors.text),
                ),
                Expanded(
                  child: Text(
                    '${_index + 1} / ${widget.ids.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: MehhColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: widget.ids.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _record(i);
                },
                itemBuilder: (_, i) {
                  final pid = widget.ids[i];
                  final out = widget.isMarked(pid);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: out ? 0.5 : 1,
                          child: LargePhoto(entity: entities[pid]),
                        ),
                        if (out)
                          Positioned(
                            left: 14,
                            top: 14,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                              decoration: BoxDecoration(
                                color: MehhColors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.close,
                                    size: 16,
                                    color: MehhColors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '정리할 사진',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: MehhColors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: marked
                    ? OutlinedButton(
                        onPressed: () => setState(() => widget.onToggle(id)),
                        child: const Text('정리 안 할래요'),
                      )
                    : FilledButton(
                        onPressed: () => setState(() => widget.onToggle(id)),
                        child: const Text('이 사진 정리'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
