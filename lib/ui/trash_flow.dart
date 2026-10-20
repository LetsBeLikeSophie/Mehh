import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'widgets.dart';

/// 화면에서 사진을 휴대폰 휴지통으로 보내는 유일한 길.
/// 실패하면 지우지 않고 알려 준다 (영구 삭제로 넘어가지 않는다).
/// 반환: 실제로 보낸 장수 (취소·실패면 0)
Future<int> sendToTrash(
  BuildContext context,
  WidgetRef ref,
  Iterable<String> ids,
) async {
  final list = ids.toSet().toList();
  if (list.isEmpty) return 0;
  int n;
  try {
    n = await ref.read(cleanerProvider).trash(list);
  } catch (_) {
    if (context.mounted) {
      showNote(context, '휴지통으로 보내지 못했어요. 사진은 그대로예요.');
    }
    return 0;
  }
  if (n > 0 && context.mounted) {
    showNote(
      context,
      '${formatCount(n)}장을 휴지통으로 보냈어요 · 갤러리 휴지통에서 30일 동안 되살릴 수 있어요',
    );
  }
  return n;
}
