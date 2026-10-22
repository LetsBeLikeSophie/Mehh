import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../providers.dart';
import 'widgets.dart';

/// 화면에서 사진을 휴대폰 휴지통으로 보내는 유일한 길.
/// 실패하면 지우지 않고 알려 준다 (영구 삭제로 넘어가지 않는다).
/// 반환: 실제로 보낸 장수 (취소·실패면 0)
Future<int> sendToTrash(
  BuildContext context,
  WidgetRef ref,
  Iterable<String> ids, {
  String Function(int n)? doneNote,
  bool quiet = false,
}) async {
  final list = ids.toSet().toList();
  if (list.isEmpty) return 0;
  int n;
  try {
    n = await ref.read(cleanerProvider).trash(list);
  } catch (_) {
    if (context.mounted) {
      showNote(context, context.l.trashFailed);
    }
    return 0;
  }
  if (n > 0 && !quiet && context.mounted) {
    showNote(context, doneNote?.call(n) ?? context.l.trashed(n));
  }
  return n;
}
