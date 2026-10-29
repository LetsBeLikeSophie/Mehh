part of '../providers.dart';

// 휴지통으로 보내기, 모든 기록 지우기

// ───────────────────────── 정리 동작

class Cleaner {
  Cleaner(this.ref);
  final Ref ref;

  /// 휴지통으로 보내고 결정·용량을 기록한다. 반환: 실제로 옮긴 장수와 그 용량.
  /// 화면에서는 [sendToTrash](ui/trash_flow.dart)를 쓴다 (실패 안내).
  Future<({int count, int bytes})> trash(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return (count: 0, bytes: 0);
    final lib = ref.read(photoLibraryProvider);
    final sizes = await lib.fileSizes(list);
    final done = await lib.trash(list);
    if (done.isEmpty) return (count: 0, bytes: 0);
    await ref.read(decisionsProvider.notifier).set(done, DecisionState.trashed);
    final bytes = done.fold<int>(0, (n, id) => n + (sizes[id] ?? 0));
    await ref
        .read(storeProvider)
        .addFreedBytes(monthKey(DateTime.now()), bytes);
    ref.invalidate(freedThisMonthProvider);
    ref.read(libraryProvider.notifier).removePhotos(done.toSet());
    await ref.read(cortexSentProvider.notifier).remove(done);
    return (count: done.length, bytes: bytes);
  }
}

final cleanerProvider = Provider((ref) => Cleaner(ref));

/// 이 폰에 남긴 모든 기록 지우기 (설정 화면). 사진 자체는 건드리지 않는다.
Future<void> clearAllRecords(WidgetRef ref) async {
  await ref.read(storeProvider).clearAll();
  // 지운 기록으로 만든 화면 상태도 바로 비운다: 바꾼 이름·Cortex 표시·"다 봤어요"·
  // 취향 학습으로 꺼 둔 이유·눈 감음 (앱을 다시 켜기 전까지 남아 있지 않게, UX-71).
  // 캐시 비우기(파일)보다 먼저: 그쪽이 늦거나 실패해도 화면은 바로 맞는다
  ref.invalidate(decisionsProvider);
  ref.invalidate(freedThisMonthProvider);
  ref.invalidate(groupNamesProvider);
  ref.invalidate(cortexSentProvider);
  ref.invalidate(seenProvider);
  ref.invalidate(mutedReasonsProvider);
  ref.invalidate(eyesClosedProvider);
  await ref.read(photoLibraryProvider).clearCache();
  await ref.read(placeNamerProvider).clearCache();
  ref.read(analysisProvider.notifier).reset();
  ref.invalidate(placeNameProvider);
  ref.read(libraryProvider.notifier).reload();
}
