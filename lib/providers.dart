import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import 'config/app_config.dart';
import 'config/cleanup_config.dart';
import 'data/billing.dart';
import 'data/demo.dart';
import 'data/device.dart';
import 'data/face_check.dart';
import 'data/handoff.dart';
import 'data/photo_library.dart';
import 'data/pro.dart';
import 'data/place_namer.dart';
import 'data/sqlite_store.dart';
import 'data/store.dart';
import 'logic/day_grouper.dart';
import 'logic/duplicates.dart';
import 'logic/pick_stats.dart';
import 'logic/recommend.dart';
import 'models/day_group.dart';
import 'models/decision.dart';
import 'models/features.dart';
import 'models/photo_meta.dart';

/// 웹은 사진첩에 접근할 수 없어 샘플 데이터로 화면만 보여준다.
const isDemo = kIsWeb;

final photoLibraryProvider = Provider<PhotoLibrary>(
  (ref) => isDemo ? DemoPhotoLibrary() : PhotoLibrary(),
);

final placeNamerProvider = Provider<PlaceNamer>(
  (ref) => isDemo
      ? DemoPlaceNamer()
      : PlaceNamer(locale: PlatformDispatcher.instance.locale),
);

final handoffProvider = Provider((ref) => Handoff());

/// Cortex가 설치돼 있으면 캡처를 Cortex로 보낼 수 있다.
/// 앱으로 돌아올 때마다 다시 묻는다: [받으러 가기]로 설치하고 돌아와도 바로 보낼 수 있게 (UX-56)
final cortexInstalledProvider = FutureProvider<bool>((ref) {
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
  return ref.read(handoffProvider).cortexInstalled();
});

final storeProvider = Provider<Store>(
  (ref) => isDemo ? MemoryStore() : SqliteStore(),
);

// ───────────────────────── Mehh Pro (SPEC 9장)

final proVaultProvider = Provider<ProVault>(
  (ref) =>
      isDemo || !storeBillingSupported ? MemoryProVault() : SecureProVault(),
);

final billingProvider = Provider<Billing>((ref) {
  final b = isDemo || !storeBillingSupported
      ? DemoBilling(
          korean: PlatformDispatcher.instance.locale.languageCode == 'ko',
        )
      : StoreBilling();
  ref.onDispose(b.dispose);
  return b;
});

class ProNotifier extends AsyncNotifier<ProState> {
  ProVault get _vault => ref.read(proVaultProvider);
  Billing get _billing => ref.read(billingProvider);

  @override
  Future<ProState> build() async {
    final s = await _vault.load();
    _billing.listen(_owned);
    // 결제 대기 중인지 기억한다: 시트를 닫았다 열어도 대기 이야기가 보이게 (UX-64)
    final sub = _billing.status.listen(
      (st) => ref
          .read(billingPendingProvider.notifier)
          .set(st == BillingStatus.pending),
    );
    ref.onDispose(sub.cancel);
    // 1년 이용권이 끝났는지, 다른 폰에서 산 게 있는지 조용히 확인
    Future.microtask(() => restore(quiet: true));
    // 새 달이 됐으면 무료 묶음이 다시 생겼다고 한 번 알린다
    Future.microtask(checkMonth);
    Future.microtask(_checkTestEnded);
    return s;
  }

  /// 비공개 테스트 동안 켠 적이 있는데 이제 테스트가 끝났으면 한 번 알린다 (2026-10-26 Sophie T1-A).
  /// 기록: closedTest 0 = 처음, 1 = 테스트 동안 켬, 2 = 끝났다고 알림
  Future<void> _checkTestEnded() async {
    try {
      final store = ref.read(storeProvider);
      final seen = await store.counter('closedTest');
      if (!ref.mounted) return;
      if (ref.read(closedTestFreeProvider)) {
        if (seen == 0) await store.bumpCounter('closedTest');
      } else if (seen == 1) {
        await store.bumpCounter('closedTest');
        if (ref.mounted) ref.read(testEndedProvider.notifier).raise();
      }
    } catch (_) {
      // 기록을 못 읽으면 알리지 않는다 (돈 상태는 그대로)
    }
  }

  /// 비공개 테스트 동안 [추천 보기]로 본 묶음: 코인 없이 사진만 기억해 둔다.
  /// 테스트가 끝나도 계속 열려 있게 (2026-10-26 Sophie T1-A)
  Future<void> keepOpen(Iterable<String> photoIds) async {
    final s = await future;
    final ids = photoIds.toSet();
    if (s.unlockedPhotos.containsAll(ids)) return;
    await _save(s.copyWith(unlockedPhotos: {...s.unlockedPhotos, ...ids}));
  }

  /// 달이 바뀌어 무료 묶음이 다시 채워졌으면 한 번 알린다 (UX 리뷰 2026-10-23 UX-40).
  /// 앱을 켤 때와 다시 열 때 부른다. 새 달 기록으로 저장해 같은 달에 두 번 뜨지 않는다.
  Future<void> checkMonth({DateTime? now}) async {
    final s = await future;
    final month = monthKey(now ?? DateTime.now());
    if (s.pro ||
        s.freeMonth.isEmpty ||
        s.freeMonth == month ||
        s.freeUsed == 0) {
      return;
    }
    await _save(s.copyWith(freeMonth: month, freeUsed: 0));
    ref.read(freeRefilledProvider.notifier).raise();
  }

  Future<void> _owned(Plan plan) async {
    ref.read(billingPendingProvider.notifier).set(false);
    final s = await future;
    await _save(
      plan == Plan.lifetime
          ? s.copyWith(lifetime: true)
          : s.copyWith(yearly: true),
    );
  }

  /// 스토어에서 가진 것을 다시 받는다. 반환: 복원된 게 있으면 true, 연결 실패면 null.
  /// 평생권은 한 번 받으면 지우지 않는다 (스토어가 잠깐 빈 답을 줘도 사용자가 잃지 않게).
  Future<bool?> restore({bool quiet = false}) async {
    final owned = await _billing.restore();
    if (owned == null) return null;
    final s = await future;
    final next = s.copyWith(
      lifetime: s.lifetime || owned.contains(Plan.lifetime),
      yearly: owned.contains(Plan.yearly),
    );
    if (next.lifetime != s.lifetime || next.yearly != s.yearly) {
      await _save(next);
    }
    // 1년 이용권이 끝나 Pro가 꺼지는 순간 한 번 알린다 (말없이 잠기지 않게, UX 리뷰 2026-10-22)
    if (s.yearly && !next.yearly && !next.lifetime) {
      ref.read(yearlyEndedProvider.notifier).raise();
    }
    return owned.isNotEmpty;
  }

  /// 묶음 추천을 연다. Pro면 그대로, 아니면 이번 달 무료 묶음을 하나 쓴다.
  /// 무료가 다 떨어졌으면 false.
  Future<bool> unlock(
    String groupId, {
    Iterable<String> photoIds = const [],
    DateTime? now,
  }) async {
    final s = await future;
    // Pro로 연 묶음도 사진을 기억해 둔다: 1년 이용권이 끝나도 계속 열려 있게 (2026-10-22 Sophie F3-A)
    if (s.pro) {
      final ids = photoIds.toSet();
      if (!s.unlockedPhotos.containsAll(ids)) {
        await _save(s.copyWith(unlockedPhotos: {...s.unlockedPhotos, ...ids}));
      }
      return true;
    }
    if (s.isOpen(groupId, photoIds: photoIds)) return true;
    final at = now ?? DateTime.now();
    if (s.freeLeft(at) == 0) return false;
    final month = monthKey(at);
    await _save(
      s.copyWith(
        unlocked: {...s.unlocked, groupId},
        unlockedPhotos: {...s.unlockedPhotos, ...photoIds},
        freeMonth: month,
        freeUsed: (s.freeMonth == month ? s.freeUsed : 0) + 1,
      ),
    );
    return true;
  }

  /// 정리를 끝낸 뒤 Pro 안내를 띄울까 (Pro가 아니고 오늘 아직 안 띄웠으면). 띄우면 기록.
  Future<bool> takeNudge({DateTime? now}) async {
    if (!await canNudge(now: now)) return false;
    final s = await future;
    await _save(s.copyWith(lastNudge: _day(now ?? DateTime.now())));
    return true;
  }

  /// [takeNudge]를 쓰지 않고 오늘 안내를 띄울 수 있는지만 본다
  Future<bool> canNudge({DateTime? now}) async {
    if (ref.read(closedTestFreeProvider)) return false; // 테스트 동안은 Pro 안내 없음
    final s = await future;
    final at = now ?? DateTime.now();
    // 무료 묶음을 다 쓴 뒤에만 (무료가 남은 사람에게는 띄우지 않는다, 2026-10-22 Sophie F1-B)
    return !s.pro && s.freeLeft(at) == 0 && s.lastNudge != _day(at);
  }

  static String _day(DateTime at) =>
      '${monthKey(at)}-${at.day.toString().padLeft(2, '0')}';

  Future<void> _save(ProState s) async {
    final was = state.value?.pro ?? false;
    await _vault.save(s);
    state = AsyncData(s);
    // Pro가 켜지는 순간 한 번 알린다: 시트 밖(결제 대기 뒤 완료, 새 폰 조용한 복원)도 (UX-36)
    if (!was && s.pro) ref.read(proStartedProvider.notifier).raise();
  }
}

/// 결제가 대기 중(가족 승인 등). 앱이 켜져 있는 동안만 기억. 산 것이 오거나 실패·취소면 내린다 (UX-64)
class BillingPendingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) => state = v;
}

final billingPendingProvider = NotifierProvider<BillingPendingNotifier, bool>(
  BillingPendingNotifier.new,
);

/// 돈이 걸린 상태가 방금 바뀌었다는 한 번짜리 신호 (홈이 알리고 내린다)
class OneShotNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void raise() => state = true;
  void clear() => state = false;
}

final yearlyEndedProvider = NotifierProvider<OneShotNotifier, bool>(
  OneShotNotifier.new,
);

/// 이번 달 무료 묶음이 방금 다시 생겼다 (홈이 한 번 알리고 내린다)
final freeRefilledProvider = NotifierProvider<OneShotNotifier, bool>(
  OneShotNotifier.new,
);

/// 비공개 테스트가 방금 끝났다 (홈이 "비공개 테스트가 끝났어요 · 이번 달 ◉ 3개"를 한 번 알린다)
final testEndedProvider = NotifierProvider<OneShotNotifier, bool>(
  OneShotNotifier.new,
);

/// Pro가 방금 켜졌다 (홈이 "Pro가 열렸어요"를 한 번 알리고 내린다)
final proStartedProvider = NotifierProvider<OneShotNotifier, bool>(
  OneShotNotifier.new,
);

final proProvider = AsyncNotifierProvider<ProNotifier, ProState>(
  ProNotifier.new,
);

/// 이 묶음의 앱 추천이 열려 있는가 (불러오는 중엔 닫힌 것으로)
/// 비공개 테스트 중 무료 ([closedTestFree]). 테스트에서는 덮어 써서 코인 흐름을 본다
final closedTestFreeProvider = Provider<bool>((ref) => closedTestFree);

final unlockedProvider = Provider.family<bool, DayGroup>(
  (ref, g) =>
      ref.watch(closedTestFreeProvider) ||
      (ref
              .watch(proProvider)
              .value
              ?.isOpen(g.id, photoIds: g.photos.map((p) => p.id)) ??
          false),
);

/// 이 폰에서 아직 잠긴 그날의 묶음과 그 추천 (Pro 안내의 "이 폰에서" 한 줄, 2026-10-26 Sophie P2-A).
/// 이미 계산해 둔 추천만 센다 (새 분석 없음)
final lockedPicksProvider =
    Provider.autoDispose<({int groups, Set<String> ids})>((ref) {
      final lib = ref.watch(libraryProvider).value;
      var groups = 0;
      final ids = <String>{};
      for (final g in lib?.groups ?? const <DayGroup>[]) {
        if (g.kind != DayGroupKind.day || ref.watch(unlockedProvider(g))) {
          continue;
        }
        final plan = ref.watch(groupPlanProvider(g));
        // 정리 화면과 같은 잠금 판단: 돈 드는 추천이 없으면(실수 사진만) 잠기지 않는다
        if (paidPickCount(plan) == 0) continue;
        groups++;
        // 장수는 정리 화면 [추천 보기 · N장]과 같은 수 (잠긴 추천 + 실수 사진)
        ids.addAll(plan.trash.keys);
      }
      return (groups: groups, ids: ids);
    });

// ───────────────────────── 권한

/// 사진 접근 권한. null = 아직 확인 전.
class PermissionNotifier extends Notifier<PermissionState?> {
  @override
  PermissionState? build() {
    _check();
    return null;
  }

  PhotoLibrary get _lib => ref.read(photoLibraryProvider);

  Future<void> _check() async => state = await _lib.permissionState();

  Future<PermissionState> request() async {
    final s = await _lib.requestPermission();
    state = s;
    return s;
  }

  Future<void> openSettings() => _lib.openSettings();

  /// 설정 화면에서 돌아왔을 때 다시 확인
  Future<void> refresh() => _check();
}

final permissionProvider =
    NotifierProvider<PermissionNotifier, PermissionState?>(
      PermissionNotifier.new,
    );

// ───────────────────────── 사진과 그날의 묶음

class LibraryState {
  const LibraryState({
    required this.photos,
    required this.groups,
    this.locating,
  });

  final List<PhotoMeta> photos;
  final List<DayGroup> groups;

  /// 위치를 읽는 중이면 (완료, 전체), 아니면 null
  final (int, int)? locating;

  LibraryState copyWith({(int, int)? locating}) => LibraryState(
    photos: photos,
    groups: groups,
    locating: locating ?? this.locating,
  );
}

/// 사진 불러오기 → 묶음. 위치는 백그라운드에서 채우고 다시 묶는다.
class LibraryNotifier extends AsyncNotifier<LibraryState> {
  List<PhotoMeta> _metas = [];
  DateTime _loadedAt = DateTime.now();

  @override
  Future<LibraryState> build() async {
    final lib = ref.read(photoLibraryProvider);
    _metas = await lib.loadAll();
    _videos = await _loadVideos();
    _loadedAt = DateTime.now();
    Future.microtask(_fillLocations);
    Future.microtask(_reviveRestored);
    return _state();
  }

  /// 갤러리 휴지통에서 되살린 사진: 사진첩에 다시 있는데 앱은 "휴지통으로 보냄"으로 기억하고 있으면
  /// 정리 화면에서 숨겨져 바깥 장수와 안 장수가 달라진다. 표시 없음으로 되돌린다 (2026-10-24 Sophie 버그)
  Future<void> _reviveRestored() async {
    final decisions = await ref.read(decisionsProvider.future);
    if (!ref.mounted) return;
    final back = <String, Decision?>{
      for (final m in _metas)
        if (decisions[m.id]?.state == DecisionState.trashed) m.id: null,
    };
    if (back.isNotEmpty) {
      await ref.read(decisionsProvider.notifier).restore(back);
    }
  }

  List<PhotoMeta> _videos = [];

  Future<List<PhotoMeta>> _loadVideos() async {
    try {
      final sizes = await ref.read(deviceProvider).videoSizes() ?? const {};
      final lib = ref.read(photoLibraryProvider);
      var videos = await lib.loadVideos(sizes);
      if (sizes.isEmpty && videos.isNotEmpty) {
        // 기기에 한 번에 물을 수 없으면 하나씩 (웹·iOS)
        final s = await lib.fileSizes([for (final v in videos) v.id]);
        videos = [
          for (final v in videos)
            PhotoMeta(
              id: v.id,
              takenAt: v.takenAt,
              width: v.width,
              height: v.height,
              isVideo: true,
              durationSec: v.durationSec,
              sizeBytes: s[v.id] ?? 0,
              isFavorite: v.isFavorite,
            ),
        ];
      }
      return videos;
    } catch (_) {
      return [];
    }
  }

  /// 큰 동영상 (용량 큰 순). ♥ 즐겨찾기는 뺀다
  List<PhotoMeta> get _bigVideos {
    final min = const CleanupConfig().bigVideoBytes;
    return [
      for (final v in _videos)
        if (v.sizeBytes >= min && !v.isFavorite) v,
    ]..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
  }

  LibraryState _state() {
    final big = _bigVideos;
    return LibraryState(
      photos: _metas,
      groups: [
        ...groupPhotos(_metas),
        if (big.isNotEmpty)
          DayGroup(id: 'videos', kind: DayGroupKind.videos, photos: big),
      ],
    );
  }

  Future<void> _fillLocations() async {
    final lib = ref.read(photoLibraryProvider);
    final found = await lib.fillLocations(
      _metas,
      onProgress: (done, total) {
        if (!ref.mounted) return;
        final cur = state.value;
        if (cur == null) return;
        state = AsyncData(cur.copyWith(locating: (done, total)));
      },
    );
    if (!ref.mounted) return;
    if (found.isNotEmpty) {
      _metas = [
        for (final m in _metas)
          if (found[m.id] case final ll?) m.withLocation(ll.$1, ll.$2) else m,
      ];
    }
    state = AsyncData(_state());
  }

  /// 휴지통으로 보낸 사진을 목록에서 뺀다.
  void removePhotos(Set<String> ids) {
    if (ids.isEmpty) return;
    _metas = _metas.where((m) => !ids.contains(m.id)).toList();
    _videos = _videos.where((m) => !ids.contains(m.id)).toList();
    state = AsyncData(_state());
  }

  void reload() => ref.invalidateSelf();

  /// 지금 바로 갤러리와 다시 맞춘다 (아래로 당겨 새로 고침)
  Future<void> syncNow() => refreshIfStale(Duration.zero);

  /// 마지막으로 불러온 지 [after]가 지났으면, 지금 목록을 보여 준 채로 뒤에서 새로 불러온다
  /// (로딩 화면으로 깜빡이지 않는다)
  Future<void> refreshIfStale(Duration after, {DateTime? now}) async {
    if (!state.hasValue ||
        (now ?? DateTime.now()).difference(_loadedAt) < after) {
      return;
    }
    _loadedAt = now ?? DateTime.now();
    final metas = await ref.read(photoLibraryProvider).loadAll();
    final videos = await _loadVideos();
    if (!ref.mounted) return;
    _metas = metas;
    _videos = videos;
    state = AsyncData(_state());
    Future.microtask(_fillLocations);
    Future.microtask(_reviveRestored);
  }
}

final libraryProvider = AsyncNotifierProvider<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);

/// 묶음 중심 좌표의 장소 이름
final placeNameProvider = FutureProvider.family<String?, (double, double)>((
  ref,
  p,
) {
  return ref.read(placeNamerProvider).nameOf(p.$1, p.$2);
});

// ───────────────────────── 사진 분석 (해시·선명도·밝기)

class AnalysisState {
  const AnalysisState({
    required this.features,
    required this.total,
    required this.done,
  });

  final Map<String, PhotoFeatures> features;
  final int total;
  final bool done;

  int get analyzed => features.length;
}

/// 새로 추가된 사진만 분석하고 결과는 DB에 캐시한다. 최신 사진부터.
class AnalysisNotifier extends Notifier<AnalysisState> {
  Map<String, PhotoFeatures>? _cache;
  int _run = 0;

  @override
  AnalysisState build() {
    final photos = ref.watch(libraryProvider.select((s) => s.value?.photos));
    final run = ++_run;
    if (photos == null) {
      return AnalysisState(features: _cache ?? const {}, total: 0, done: false);
    }
    Future.microtask(() => _start(photos, run));
    final present = {for (final p in photos) p.id};
    final cache = _cache;
    // 사진이 빠지기만 한 경우(휴지통으로 보냄)는 이미 다 분석돼 있어서 바로 끝난 상태로 둔다.
    // 그래야 중복·추천이 "살펴보는 중"으로 깜빡이지 않는다.
    final allCached =
        cache != null &&
        photos.every((p) => cache[p.id]?.modifiedAt == p.modifiedAt);
    return AnalysisState(
      features: {
        for (final e in (cache ?? const <String, PhotoFeatures>{}).entries)
          if (present.contains(e.key)) e.key: e.value,
      },
      total: photos.length,
      done: allCached,
    );
  }

  bool _stale(int run) => run != _run || !ref.mounted;

  /// 기록 지우기 후 처음부터 다시 분석
  void reset() {
    _cache = null;
    ref.invalidateSelf();
  }

  Future<void> _start(List<PhotoMeta> photos, int run) async {
    final store = ref.read(storeProvider);
    final cache = _cache ??= await store.loadFeatures();
    if (_stale(run)) return;

    final todo =
        photos.where((p) => cache[p.id]?.modifiedAt != p.modifiedAt).toList()
          ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    final present = {for (final p in photos) p.id};

    void emit({required bool done}) {
      state = AnalysisState(
        features: Map.unmodifiable({
          for (final e in cache.entries)
            if (present.contains(e.key)) e.key: e.value,
        }),
        total: photos.length,
        done: done,
      );
    }

    emit(done: todo.isEmpty);
    if (todo.isEmpty) return;

    var lastEmit = DateTime.now();
    await ref
        .read(photoLibraryProvider)
        .analyze(
          todo,
          cancelled: () => _stale(run),
          onBatch: (list) async {
            for (final f in list) {
              cache[f.id] = f;
            }
            await store.saveFeatures(list);
            if (_stale(run)) return;
            if (DateTime.now().difference(lastEmit).inMilliseconds > 800) {
              lastEmit = DateTime.now();
              emit(done: false);
            }
          },
        );
    if (_stale(run)) return;
    emit(done: true);
  }
}

final analysisProvider = NotifierProvider<AnalysisNotifier, AnalysisState>(
  AnalysisNotifier.new,
);

// ───────────────────────── 사용자 결정

class DecisionsNotifier extends AsyncNotifier<Map<String, Decision>> {
  @override
  Future<Map<String, Decision>> build() =>
      ref.read(storeProvider).loadDecisions();

  /// 결정을 바꾸고, 되돌리기용으로 이전 결정을 돌려준다.
  Future<Map<String, Decision?>> set(
    Iterable<String> ids,
    DecisionState s,
  ) async {
    final now = DateTime.now();
    final cur = state.value ?? {};
    final before = {for (final id in ids) id: cur[id]};
    final list = [
      for (final id in ids) Decision(photoId: id, state: s, at: now),
    ];
    // 저장을 기다리는 사이 다른 결정이 들어올 수 있다(끌어서 여러 장 선택): 지금 상태 위에 더한다
    state = AsyncData({
      ...state.value ?? {},
      for (final d in list) d.photoId: d,
    });
    await ref.read(storeProvider).saveDecisions(list);
    return before;
  }

  /// [set]이 돌려준 이전 결정으로 되돌린다.
  Future<void> restore(Map<String, Decision?> before) async {
    final now = DateTime.now();
    final list = [
      for (final e in before.entries)
        e.value ??
            Decision(photoId: e.key, state: DecisionState.undecided, at: now),
    ];
    await ref.read(storeProvider).saveDecisions(list);
    state = AsyncData({
      ...state.value ?? {},
      for (final d in list) d.photoId: d,
    });
  }
}

final decisionsProvider =
    AsyncNotifierProvider<DecisionsNotifier, Map<String, Decision>>(
      DecisionsNotifier.new,
    );

/// 사진의 결정 상태. 예전에 저장된 보류는 표시 없음(undecided)으로 본다.
DecisionState stateOf(Map<String, Decision> decisions, String id) {
  final s = decisions[id]?.state;
  return s == null || s == DecisionState.hold ? DecisionState.undecided : s;
}

// ───────────────────────── 열람 기록, 비운 용량

class ViewsNotifier extends AsyncNotifier<Map<String, ViewRecord>> {
  @override
  Future<Map<String, ViewRecord>> build() =>
      ref.read(storeProvider).loadViews();

  Future<void> record(String id) async {
    final now = DateTime.now();
    await ref.read(storeProvider).recordView(id, now);
    final cur = state.value ?? {};
    state = AsyncData({
      ...cur,
      id: ViewRecord(count: (cur[id]?.count ?? 0) + 1, lastAt: now),
    });
  }
}

final viewsProvider =
    AsyncNotifierProvider<ViewsNotifier, Map<String, ViewRecord>>(
      ViewsNotifier.new,
    );

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
  ref.invalidate(viewsProvider);
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

// ───────────────────────── 파생 데이터

/// 완전 중복. 분석이 끝나기 전에는 null.
final duplicatesProvider = FutureProvider<List<DuplicateSet>?>((ref) async {
  final photos = ref.watch(libraryProvider.select((s) => s.value?.photos));
  final analysis = ref.watch(analysisProvider);
  if (photos == null || !analysis.done) return null;
  final features = analysis.features;
  final need = await compute(_needSize, (photos, features));
  final sizes = await ref.read(photoLibraryProvider).fileSizes(need);
  return compute(_findDups, (photos, features, sizes));
});

Set<String> _needSize((List<PhotoMeta>, Map<String, PhotoFeatures>) a) =>
    idsNeedingSize(a.$1, a.$2);

List<DuplicateSet> _findDups(
  (List<PhotoMeta>, Map<String, PhotoFeatures>, Map<String, int>) a,
) => findDuplicates(a.$1, a.$2, sizes: a.$3);

/// 아직 고르지 않은 똑같은 사진 수 (홈 카드). 킵·휴지통으로 간 것은 빠진다.
int duplicatesLeft(List<DuplicateSet>? sets, Map<String, Decision> decisions) =>
    sets == null
    ? 0
    : sets.expand((s) => s.remove).where((p) {
        final st = stateOf(decisions, p.id);
        return st == DecisionState.undecided || st == DecisionState.toTrash;
      }).length;

/// 묶음 하나의 추천 정리
/// 자주 되돌린 추천 이유 (취향 학습). 추천 정확도 기록에서 계산하고, 기록이 쌓이면 다시 계산한다.
final mutedReasonsProvider = FutureProvider<Set<TrashReason>>(
  (ref) async => mutedReasons(
    PickStats.of(
      recentPicks(
        await ref.read(storeProvider).loadPicks(),
        now: DateTime.now(),
      ),
    ),
  ),
);

final groupPlanProvider = Provider.autoDispose.family<GroupPlan, DayGroup>((
  ref,
  g,
) {
  final features = ref.watch(analysisProvider.select((s) => s.features));
  final decisions = ref.watch(decisionsProvider).value ?? const {};
  final muted = ref.watch(mutedReasonsProvider).value ?? const {};
  final eyes = ref.watch(eyesClosedProvider).value ?? const {};
  return planGroup(
    g.photos,
    features,
    decisions,
    muted: muted,
    eyesClosed: {
      for (final e in eyes.entries)
        if (e.value) e.key,
    },
  );
});

/// [g]에 붙은 이름의 저장 키. 먼저 묶음 id, 없으면 사진이 가장 많이 겹치는 이름
/// (첫 사진을 지우면 묶음 id가 바뀌어도 이름이 남게, 코인 열림과 같은 방식)
/// 겹침으로 찾기는 그날의 묶음(day-*)끼리만, 그리고 한 이름은 지금 묶음들([all]) 중
/// 가장 많이 겹치는 한 곳에만 (낱장 사진으로 옮겨 간 1장이나 둘로 갈라진 다른 쪽이
/// 이름을 가져가지 않게, UX-47)
String? groupNameKey(
  Map<String, GroupName>? names,
  DayGroup? g, {
  Iterable<DayGroup> all = const [],
}) {
  if (names == null || g == null) return null;
  if (names.containsKey(g.id)) return g.id;
  if (g.kind != DayGroupKind.day) return null;
  int overlap(DayGroup d, GroupName v) =>
      d.photos.where((p) => v.photoIds.contains(p.id)).length;
  String? best;
  var most = 0;
  for (final e in names.entries) {
    if (!e.key.startsWith('day-')) continue;
    final n = overlap(g, e.value);
    if (n == 0) continue;
    // 그 이름의 원래 묶음이 아직 있거나, 더 많이(같게) 겹치는 다른 묶음이 있으면 양보
    final taken = all.any(
      (o) =>
          o.id != g.id &&
          (o.id == e.key ||
              (o.kind == DayGroupKind.day && overlap(o, e.value) >= n)),
    );
    if (taken) continue;
    if (n > most) {
      most = n;
      best = e.key;
    }
  }
  return best;
}

/// 정리 화면을 연 뒤 사진첩이 바뀌었으면(새로 찍은 사진·다시 묶임) 지금의 같은 묶음.
/// 같은 종류에서 그날의 묶음은 같은 id 먼저, 아니면 사진이 가장 많이 겹치는 것. 못 찾으면 [old]
/// (열어 둔 정리 화면도 새 캡처를 보게, UX-70 2026-10-27)
DayGroup? freshGroup(List<DayGroup> groups, DayGroup? old) {
  if (old == null) return null;
  final ids = {for (final p in old.photos) p.id};
  DayGroup? best;
  var most = 0;
  for (final g in groups) {
    if (g.kind != old.kind) continue;
    if (g.kind == DayGroupKind.day && g.id == old.id) return g;
    final n = g.photos.where((p) => ids.contains(p.id)).length;
    if (n > most) {
      most = n;
      best = g;
    }
  }
  return best ?? old;
}

/// [g]의 바꾼 이름. 없으면 null (기본 이름을 쓴다)
String? groupNameOf(
  Map<String, GroupName>? names,
  DayGroup? g, {
  Iterable<DayGroup> all = const [],
}) => names?[groupNameKey(names, g, all: all)]?.name;

/// 사용자가 바꾼 묶음 이름 (2026-10-24 Sophie). 기본 이름은 따로 계산하므로 언제든 되돌릴 수 있다
class GroupNamesNotifier extends AsyncNotifier<Map<String, GroupName>> {
  @override
  Future<Map<String, GroupName>> build() => ref.read(storeProvider).loadNames();

  /// [name]이 비었거나 null이면 기본 이름으로 되돌린다
  Future<void> rename(DayGroup group, String? name) async {
    final v = name?.trim();
    final keep = v == null || v.isEmpty ? null : v;
    final store = ref.read(storeProvider);
    final next = {...state.value ?? {}};
    // 옛 id로 남아 있던 이름은 지금 id로 옮긴다
    final old = groupNameKey(
      next,
      group,
      all: ref.read(libraryProvider).value?.groups ?? const [],
    );
    if (old != null && old != group.id) {
      await store.saveName(old, null);
      next.remove(old);
    }
    final ids = [for (final p in group.photos) p.id];
    await store.saveName(group.id, keep, photoIds: ids);
    if (keep == null) {
      next.remove(group.id);
    } else {
      next[group.id] = GroupName(keep, ids.toSet());
    }
    state = AsyncData(next);
  }
}

final groupNamesProvider =
    AsyncNotifierProvider<GroupNamesNotifier, Map<String, GroupName>>(
      GroupNamesNotifier.new,
    );

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

/// "다 봤어요" 기준 (2026-10-21): 모든 사진을 정할 필요 없이, 추천을 다 처리하면 끝.
/// 표시 없는 사진은 앱이 다시 추천하지 않으니 그대로 둔다.
/// 잠긴 채로 직접 정리해 보낸 묶음의 사진 (R3, [Store.addSeen])
class SeenNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() => ref.read(storeProvider).loadSeen();

  Future<void> mark(Iterable<String> photoIds) async {
    final ids = photoIds.toList();
    if (ids.isEmpty) return;
    await ref.read(storeProvider).addSeen(ids);
    state = AsyncData({...state.value ?? {}, ...ids});
  }
}

final seenProvider = AsyncNotifierProvider<SeenNotifier, Set<String>>(
  SeenNotifier.new,
);

/// Cortex로 보낸 사진 → Cortex가 받았는지 ([Store.addCortexSent])
class CortexSentNotifier extends AsyncNotifier<Map<String, bool>> {
  @override
  Future<Map<String, bool>> build() => ref.read(storeProvider).loadCortexSent();

  Future<void> add(Iterable<String> photoIds, {bool got = false}) async {
    final ids = photoIds.toList();
    if (ids.isEmpty) return;
    await ref.read(storeProvider).addCortexSent(ids, got: got);
    state = AsyncData({...state.value ?? {}, for (final id in ids) id: got});
  }

  Future<void> remove(Iterable<String> photoIds) async {
    final now = state.value ?? const {};
    final ids = photoIds.where(now.containsKey).toList();
    if (ids.isEmpty) return;
    await ref.read(storeProvider).removeCortexSent(ids);
    state = AsyncData({...now}..removeWhere((k, _) => ids.contains(k)));
  }
}

final cortexSentProvider =
    AsyncNotifierProvider<CortexSentNotifier, Map<String, bool>>(
      CortexSentNotifier.new,
    );

final groupStatusProvider = Provider.autoDispose.family<GroupStatus, DayGroup>((
  ref,
  g,
) {
  final decisions = ref.watch(decisionsProvider).value ?? const {};
  final pile = g.photos.any(
    (p) => stateOf(decisions, p.id) == DecisionState.toTrash,
  );
  final touched = g.photos.any(
    (p) => stateOf(decisions, p.id) != DecisionState.undecided,
  );
  // 캡처 추천(C4)은 무료이고 [추천 보기]로 받는다. 홈의 "정리할 묶음 N개"에 캡처를 셀지는 아직 정하지 않아서
  // 상태는 X가 있을 때만 할 일로 둔다 (줄 아래 글자는 캡처 추천 장수를 보여 준다)
  // 큰 동영상: 앱 추천이 없다. 선택해 두면 할 일, 아니면 그대로
  if (g.kind == DayGroupKind.videos) {
    return pile ? GroupStatus.needsWork : GroupStatus.nothing;
  }
  if (g.kind == DayGroupKind.screenshots) {
    if (pile) return GroupStatus.needsWork;
    // 캡처 추천이 남아 있으면 "다 봤어요"가 아니다 (UX 리뷰 2026-10-23). 큰 숫자에는 세지 않는다
    final picks = planScreenshots(
      g.photos,
      ref.watch(analysisProvider.select((a) => a.features)),
      decisions,
      now: DateTime.now(),
    );
    if (picks.isNotEmpty) return GroupStatus.nothing;
    return touched ? GroupStatus.done : GroupStatus.nothing;
  }
  final plan = ref.watch(groupPlanProvider(g));
  if (pile) return GroupStatus.needsWork;
  if (plan.trash.isNotEmpty) {
    // 잠긴 묶음을 추천 없이 직접 정리해 한 번 보냈으면 "다 봤어요" (보이지 않는 추천으로 남지 않게)
    final seen = ref.watch(seenProvider).value ?? const {};
    final locked =
        g.kind == DayGroupKind.day && !ref.watch(unlockedProvider(g));
    if (locked && g.photos.any((p) => seen.contains(p.id))) {
      return GroupStatus.done;
    }
    return GroupStatus.needsWork;
  }
  if (plan.analyzed < g.count) return GroupStatus.analyzing;
  return touched ? GroupStatus.done : GroupStatus.nothing;
});
