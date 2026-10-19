import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/cleanup_config.dart';
import '../models/day_group.dart';
import '../models/features.dart';
import '../providers.dart';
import '../theme.dart';
import 'photo_viewer.dart';
import 'widgets.dart';

/// 캡처: 고르기 → 다른 앱으로 보내기 → 정리.
/// 캡처는 이유가 있어서 찍었으니 바로 지우지 않고, 필요한 앱으로 넘긴 뒤 정리한다.
class ScreenshotsScreen extends ConsumerStatefulWidget {
  const ScreenshotsScreen({super.key, required this.group});

  final DayGroup group;

  @override
  ConsumerState<ScreenshotsScreen> createState() => _ScreenshotsScreenState();
}

/// 캡처 나눠 보기: 전체 / 글자 있는 캡처 / 그 외 (폰 안 픽셀 계산이라 완벽하진 않다)
enum _Filter { all, text, other }

class _ScreenshotsScreenState extends ConsumerState<ScreenshotsScreen> {
  final _selected = <String>{};
  final _gone = <String>{};
  bool _busy = false;
  _Filter _filter = _Filter.all;

  List<String> get _allIds => [
    for (final p in widget.group.photos.reversed)
      if (!_gone.contains(p.id)) p.id,
  ];

  bool _isText(String id, Map<String, PhotoFeatures> features) =>
      (features[id]?.textScore ?? 0) >= const CleanupConfig().textScreenshot;

  Future<void> _trash(Set<String> ids) async {
    final n = await ref.read(cleanerProvider).trash(ids);
    if (!mounted || n == 0) return;
    setState(() {
      _gone.addAll(ids);
      _selected.removeAll(ids);
    });
    showNote(context, '${formatCount(n)}장을 휴지통으로 보냈어요');
  }

  Future<void> _send() async {
    final ids = {..._selected};
    setState(() => _busy = true);
    final sent = await ref.read(photoLibraryProvider).share(ids.toList());
    if (!mounted) return;
    setState(() => _busy = false);
    if (!sent) return;
    final clean = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MehhColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MehhRadius.card),
        ),
        title: Text(
          '보낸 ${formatCount(ids.length)}장을 정리할까요?',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          '휴지통으로 보내고, 30일 안에 되살릴 수 있어요.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            style: TextButton.styleFrom(foregroundColor: MehhColors.textMuted),
            child: const Text('나중에'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: TextButton.styleFrom(foregroundColor: MehhColors.black),
            child: const Text(
              '정리',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (clean == true) await _trash(ids);
  }

  @override
  Widget build(BuildContext context) {
    final entities = ref.read(photoLibraryProvider).entities;
    final features = ref.watch(analysisProvider.select((s) => s.features));
    final all = _allIds;
    final textCount = all.where((id) => _isText(id, features)).length;
    final ids = switch (_filter) {
      _Filter.all => all,
      _Filter.text => [
        for (final id in all)
          if (_isText(id, features)) id,
      ],
      _Filter.other => [
        for (final id in all)
          if (!_isText(id, features)) id,
      ],
    };
    final allSelected = ids.isNotEmpty && ids.every(_selected.contains);
    final n = _selected.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 20, 8),
                    sliver: SliverList.list(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: '홈으로',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.chevron_left,
                              color: MehhColors.text,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '캡처 ${formatCount(all.length)}장',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '캡처는 이유가 있어서 찍었죠. 필요한 건 메모·정리 앱으로 '
                                '보내두고, 여기선 정리해요.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: MehhColors.textMuted,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                children: [
                                  _FilterChip(
                                    '전체 ${formatCount(all.length)}',
                                    on: _filter == _Filter.all,
                                    onTap: () =>
                                        setState(() => _filter = _Filter.all),
                                  ),
                                  _FilterChip(
                                    '글자 있음 ${formatCount(textCount)}',
                                    on: _filter == _Filter.text,
                                    onTap: () =>
                                        setState(() => _filter = _Filter.text),
                                  ),
                                  _FilterChip(
                                    '그 외 ${formatCount(all.length - textCount)}',
                                    on: _filter == _Filter.other,
                                    onTap: () =>
                                        setState(() => _filter = _Filter.other),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      n == 0
                                          ? '눌러서 고르세요'
                                          : '${formatCount(n)}장 골랐어요',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: MehhColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() {
                                      allSelected
                                          ? _selected.removeAll(ids)
                                          : _selected.addAll(ids);
                                    }),
                                    style: TextButton.styleFrom(
                                      foregroundColor: MehhColors.text,
                                      minimumSize: const Size(44, 44),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Text(
                                      allSelected ? '선택 해제' : '전체 선택',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            childAspectRatio: 0.6,
                          ),
                      itemCount: ids.length,
                      itemBuilder: (_, i) {
                        final id = ids[i];
                        final on = _selected.contains(id);
                        return GestureDetector(
                          onTap: () => setState(
                            () => on ? _selected.remove(id) : _selected.add(id),
                          ),
                          onLongPress: () => openPhoto(context, id),
                          child: Semantics(
                            button: true,
                            selected: on,
                            label: '캡처',
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                PhotoThumb(entity: entities[id], size: 240),
                                if (on)
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: MehhColors.black,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        MehhRadius.thumb,
                                      ),
                                    ),
                                  ),
                                if (on)
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(
                                        color: MehhColors.black,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        size: 12,
                                        color: MehhColors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: n == 0 || _busy ? null : _send,
                      child: Text(
                        n == 0 ? '보내기' : '${formatCount(n)}장 보내기',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: n == 0 || _busy
                          ? null
                          : () => _trash({..._selected}),
                      child: Text(
                        n == 0 ? '정리' : '${formatCount(n)}장 정리',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(this.text, {required this.on, required this.onTap});

  final String text;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? MehhColors.black : MehhColors.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: on ? FontWeight.w600 : FontWeight.w400,
              color: on ? MehhColors.white : MehhColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
