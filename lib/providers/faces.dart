part of '../providers.dart';

// 눈 감은 컷 (폰 안 AI)

// ───────────────────────── 눈 감은 컷 (폰 안 AI)

final faceCheckerProvider = Provider<FaceChecker>((ref) {
  if (isDemo || !(Platform.isAndroid || Platform.isIOS)) return NoFaceChecker();
  final c = MlKitFaceChecker(ref.read(photoLibraryProvider).entities);
  ref.onDispose(c.close);
  return c;
});

/// 사진 id → 눈 감은 얼굴이 있다 (폰 안 ML Kit 결과, 기기 안 `faces` 표). 얼굴 정보는 남기지 않는다
class EyesClosedNotifier extends AsyncNotifier<Map<String, bool>> {
  @override
  Future<Map<String, bool>> build() => ref.read(storeProvider).loadFaces();

  bool _running = false;

  /// 아직 안 본 사진만 차례로 본다 (몇 장씩 저장하며 화면에 반영)
  Future<void> scan(List<String> ids) async {
    if (_running) return;
    _running = true;
    try {
      final have = await future;
      final todo = [
        for (final id in ids)
          if (!have.containsKey(id)) id,
      ];
      for (var i = 0; i < todo.length; i += 12) {
        if (!ref.mounted) return;
        final part = todo.sublist(i, (i + 12).clamp(0, todo.length));
        final found = await ref.read(faceCheckerProvider).eyesClosed(part);
        // 못 본 사진도 다시 안 보게 "눈 감음 아님"으로 남긴다
        final result = {for (final id in part) id: found[id] ?? false};
        await ref.read(storeProvider).saveFaces(result);
        if (!ref.mounted) return;
        state = AsyncData({...state.value ?? {}, ...result});
      }
    } finally {
      _running = false;
    }
  }
}

final eyesClosedProvider =
    AsyncNotifierProvider<EyesClosedNotifier, Map<String, bool>>(
      EyesClosedNotifier.new,
    );

/// 사진 분석이 끝나면 연속 컷(2장 이상)에 든 사진만 눈 감음을 본다. 최근 묶음부터.
/// 홈이 지켜보는 동안 돈다
final faceScanProvider = Provider<void>((ref) {
  final done = ref.watch(analysisProvider.select((a) => a.done));
  final groups = ref.watch(libraryProvider.select((s) => s.value?.groups));
  if (!done ||
      groups == null ||
      ref.read(faceCheckerProvider) is NoFaceChecker) {
    return;
  }
  final features = ref.read(analysisProvider).features;
  final ids = <String>[
    for (final g in groups.reversed)
      if (g.kind == DayGroupKind.day || g.kind == DayGroupKind.singles)
        for (final b in findBursts(g.photos, features))
          if (b.length > 1)
            for (final p in b) p.id,
  ];
  Future.microtask(() => ref.read(eyesClosedProvider.notifier).scan(ids));
});

/// 묶음 상태 (홈 목록·"정리할 묶음 N개")
enum GroupStatus {
  /// 아직 사진을 살펴보는 중
  analyzing,

  /// 정리할 사진이 있다 (앱 추천이 남았거나, 사용자가 X를 쳐 두고 아직 안 보냄)
  needsWork,

  /// 추천을 다 처리했다 (휴지통으로 보냈거나 X를 꺼서 남김)
  done,

  /// 앱이 찾은 게 없고 손댄 것도 없다
  nothing,
}
