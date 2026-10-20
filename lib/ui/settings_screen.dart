import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme.dart';
import 'widgets.dart';

/// 설정: 개인정보 안내 + 이 폰에 남긴 기록 지우기
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MehhColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MehhRadius.card),
        ),
        title: const Text(
          '모든 기록을 지울까요?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          '사진 분석 결과, 킵·보류·정리 줄 기록, 배운 취향, 비운 용량 기록을 지워요.\n'
          '사진은 지워지지 않아요.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            style: TextButton.styleFrom(foregroundColor: MehhColors.textMuted),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: TextButton.styleFrom(foregroundColor: MehhColors.black),
            child: const Text(
              '지우기',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await clearAllRecords(ref);
    if (context.mounted) showNote(context, '기록을 모두 지웠어요');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 4, 20, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: '홈으로',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.chevron_left, color: MehhColors.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '설정',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _Section(
                    title: '사진과 기록은 이 폰에만 있어요',
                    lines: [
                      '사진 분석, 정리·보류 기록, 배운 취향은 이 폰 안에만 저장돼요. '
                          '서버로 보내지 않고, 클라우드 백업에도 넣지 않아요.',
                      '장소 이름을 찾을 때는 사진의 위치 좌표만 휴대폰의 위치 서비스로 보내요.',
                      '정리한 사진은 휴대폰 휴지통으로 가서 30일 안에 갤러리 앱에서 되살릴 수 있어요.',
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _confirmClear(context, ref),
                      child: const Text('모든 기록 지우기'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Mehh 1.0.5',
                    style: TextStyle(fontSize: 12, color: MehhColors.textMuted),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MehhColors.surface,
        borderRadius: BorderRadius.circular(MehhRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          for (final l in lines) ...[
            const SizedBox(height: 8),
            Text(
              l,
              style: const TextStyle(
                fontSize: 13,
                color: MehhColors.textMuted,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
