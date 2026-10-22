import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import 'data/billing.dart';
import 'data/demo.dart';
import 'data/handoff.dart';
import 'data/photo_library.dart';
import 'data/pro.dart';
import 'data/place_namer.dart';
import 'data/sqlite_store.dart';
import 'data/store.dart';
import 'logic/day_grouper.dart';
import 'logic/duplicates.dart';
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

/// Cortex가 설치돼 있으면 캡처를 Cortex로 보낼 수 있다
final cortexInstalledProvider = FutureProvider<bool>(
  (ref) => ref.read(handoffProvider).cortexInstalled(),
);

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
    // 1년 이용권이 끝났는지, 다른 폰에서 산 게 있는지 조용히 확인
    Future.microtask(() => restore(quiet: true));
    return s;
  }

  Future<void> _owned(Plan plan) async {
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
    final s = await future;
    final at = now ?? DateTime.now();
    final day = '${monthKey(at)}-${at.day.toString().padLeft(2, '0')}';
    if (s.pro || s.lastNudge == day) return false;
    await _save(s.copyWith(lastNudge: day));
    return true;
  }

  Future<void> _save(ProState s) async {
    await _vault.save(s);
    state = AsyncData(s);
  }
}

final proProvider = AsyncNotifierProvider<ProNotifier, ProState>(
  ProNotifier.new,
);

/// 이 묶음의 앱 추천이 열려 있는가 (불러오는 중엔 닫힌 것으로)
final unlockedProvider = Provider.family<bool, DayGroup>(
  (ref, g) =>
      ref
          .watch(proProvider)
          .value
          ?.isOpen(g.id, photoIds: g.photos.map((p) => p.id)) ??
      false,
);

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

  @override
  Future<LibraryState> build() async {
    final lib = ref.read(photoLibraryProvider);
    _metas = await lib.loadAll();
    Future.microtask(_fillLocations);
    return _state();
  }

  LibraryState _state() =>
      LibraryState(photos: _metas, groups: groupPhotos(_metas));

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
    state = AsyncData(_state());
  }

  void reload() => ref.invalidateSelf();
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
    await ref.read(storeProvider).saveDecisions(list);
    state = AsyncData({...cur, for (final d in list) d.photoId: d});
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

// ───────────────────────── 정리 동작

class Cleaner {
  Cleaner(this.ref);
  final Ref ref;

  /// 휴지통으로 보내고 결정·용량을 기록한다. 반환: 실제로 옮긴 장수.
  /// 화면에서는 [sendToTrash](ui/trash_flow.dart)를 쓴다 (실패 안내).
  Future<int> trash(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return 0;
    final lib = ref.read(photoLibraryProvider);
    final sizes = await lib.fileSizes(list);
    final done = await lib.trash(list);
    if (done.isEmpty) return 0;
    await ref.read(decisionsProvider.notifier).set(done, DecisionState.trashed);
    final bytes = done.fold<int>(0, (n, id) => n + (sizes[id] ?? 0));
    await ref
        .read(storeProvider)
        .addFreedBytes(monthKey(DateTime.now()), bytes);
    ref.invalidate(freedThisMonthProvider);
    ref.read(libraryProvider.notifier).removePhotos(done.toSet());
    return done.length;
  }
}

final cleanerProvider = Provider((ref) => Cleaner(ref));

/// 이 폰에 남긴 모든 기록 지우기 (설정 화면). 사진 자체는 건드리지 않는다.
Future<void> clearAllRecords(WidgetRef ref) async {
  await ref.read(storeProvider).clearAll();
  await ref.read(photoLibraryProvider).clearCache();
  await ref.read(placeNamerProvider).clearCache();
  ref.invalidate(decisionsProvider);
  ref.invalidate(viewsProvider);
  ref.invalidate(freedThisMonthProvider);
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
final groupPlanProvider = Provider.autoDispose.family<GroupPlan, DayGroup>((
  ref,
  g,
) {
  final features = ref.watch(analysisProvider.select((s) => s.features));
  final decisions = ref.watch(decisionsProvider).value ?? const {};
  return planGroup(g.photos, features, decisions);
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
  // 캡처는 앱이 추천하지 않는다 (정리 화면 SortSource와 같은 기준): X가 있을 때만 할 일
  if (g.kind == DayGroupKind.screenshots) {
    if (pile) return GroupStatus.needsWork;
    return touched ? GroupStatus.done : GroupStatus.nothing;
  }
  final plan = ref.watch(groupPlanProvider(g));
  if (plan.trash.isNotEmpty || pile) return GroupStatus.needsWork;
  if (plan.analyzed < g.count) return GroupStatus.analyzing;
  return touched ? GroupStatus.done : GroupStatus.nothing;
});
