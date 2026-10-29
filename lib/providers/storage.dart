part of '../providers.dart';

// 용량 막대 (사진·동영상 용량, 추천 정리, 선택)

// ───────────────────────── 비운 용량

final freedThisMonthProvider = FutureProvider<int>(
  (ref) => ref.read(storeProvider).freedBytes(monthKey(DateTime.now())),
);

final deviceProvider = Provider((ref) => Device());

/// 사진·동영상 전체 용량 (막대 전체, 2026-10-26 Sophie V2-A). 사진·큰 동영상이 바뀌면 다시 센다.
/// 기기에 물어보고(모든 동영상 포함), 모르면(웹·테스트) 사진마다 크기 + 큰 동영상 크기를 더한다
final photoBytesProvider = FutureProvider<int>((ref) async {
  final photos = ref.watch(libraryProvider.select((s) => s.value?.photos));
  if (photos == null) return 0;
  final videos = ref.watch(libraryProvider.select((s) => _videosOf(s.value)));
  final n = await ref.read(deviceProvider).photoBytes();
  if (n != null) return n;
  final sizes = await ref.read(photoLibraryProvider).fileSizes([
    for (final p in photos) p.id,
  ]);
  return sizes.values.fold<int>(0, (a, b) => a + b) +
      videos.fold<int>(0, (a, v) => a + v.sizeBytes);
});

/// 큰 동영상 묶음의 동영상들 (없으면 빈 목록)
List<PhotoMeta> _videosOf(LibraryState? s) => [
  for (final g in s?.groups ?? const <DayGroup>[])
    if (g.kind == DayGroupKind.videos) ...g.photos,
];

/// 비울 수 있는 사진: 선택한 것(X) + 앱 추천(그날의 묶음·낱장·캡처·똑같은 사진).
/// 막대의 진한 회색 (2026-10-24 Sophie)
final cleanableIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final lib = ref.watch(libraryProvider).value;
  if (lib == null) return const {};
  final decisions = ref.watch(decisionsProvider).value ?? const {};
  final features = ref.watch(analysisProvider.select((a) => a.features));
  final out = <String>{
    for (final p in lib.photos)
      if (stateOf(decisions, p.id) == DecisionState.toTrash) p.id,
  };
  for (final g in lib.groups) {
    if (g.kind == DayGroupKind.videos) continue; // 큰 동영상은 앱이 추천하지 않는다
    if (g.kind == DayGroupKind.screenshots) {
      out.addAll(
        planScreenshots(
          g.photos,
          features,
          decisions,
          now: DateTime.now(),
        ).keys,
      );
    } else {
      out.addAll(ref.watch(groupPlanProvider(g)).trash.keys);
    }
  }
  for (final set in ref.watch(duplicatesProvider).value ?? const []) {
    for (final p in set.remove) {
      final st = stateOf(decisions, p.id);
      if (st == DecisionState.undecided || st == DecisionState.toTrash) {
        out.add(p.id);
      }
    }
  }
  return out;
});

/// 선택한 사진(X, 아직 안 보냄). 묶음 안 막대의 진한 회색
final selectedIdsProvider = Provider<Set<String>>((ref) {
  final photos = ref.watch(libraryProvider.select((s) => s.value?.photos));
  final videos = ref.watch(libraryProvider.select((s) => _videosOf(s.value)));
  final decisions = ref.watch(decisionsProvider).value ?? const {};
  // 선택해 둔 큰 동영상도 막대의 추천 정리에 (V2-A)
  return {
    for (final p in [...?photos, ...videos])
      if (stateOf(decisions, p.id) == DecisionState.toTrash) p.id,
  };
});

/// 사진 몇 장의 용량 합. 키는 정렬한 id를 쉼표로 이은 것
final idsBytesProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  key,
) async {
  if (key.isEmpty) return 0;
  final sizes = await ref.read(photoLibraryProvider).fileSizes(key.split(','));
  return sizes.values.fold<int>(0, (a, b) => a + b);
});
