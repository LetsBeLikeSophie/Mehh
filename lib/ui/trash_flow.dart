import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme.dart';
import 'widgets.dart';

/// 화면에서 사진을 휴대폰 휴지통으로 보내는 유일한 길.
/// - 휴지통이 없는 폰(안드로이드 10 이하)은 "바로 지워져요"를 먼저 묻는다.
/// - 실패하면 지우지 않고 알려 준다 (영구 삭제로 넘어가지 않는다).
/// 반환: 실제로 보낸 장수 (취소·실패면 0)
Future<int> sendToTrash(
  BuildContext context,
  WidgetRef ref,
  Iterable<String> ids,
) async {
  final list = ids.toSet().toList();
  if (list.isEmpty) return 0;
  var permanent = false;
  if (!await ref.read(photoLibraryProvider).hasTrash()) {
    if (!context.mounted) return 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MehhColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MehhRadius.card),
        ),
        title: const Text(
          '이 폰은 휴지통이 없어요',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '안드로이드 10 이하는 휴지통이 없어서 ${formatCount(list.length)}장이 '
          '바로 지워지고 되살릴 수 없어요. 지울까요?',
          style: const TextStyle(fontSize: 14, height: 1.5),
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
              '바로 지우기',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return 0;
    permanent = true;
  }

  int n;
  try {
    n = await ref.read(cleanerProvider).trash(list, permanentOk: permanent);
  } catch (_) {
    if (context.mounted) {
      showNote(context, '휴지통으로 보내지 못했어요. 사진은 그대로예요.');
    }
    return 0;
  }
  if (n > 0 && context.mounted) {
    showNote(
      context,
      permanent
          ? '${formatCount(n)}장을 지웠어요'
          : '${formatCount(n)}장을 휴지통으로 보냈어요 · 갤러리 휴지통에서 30일 동안 되살릴 수 있어요',
    );
  }
  return n;
}
