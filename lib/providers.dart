import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import 'data/demo.dart';
import 'data/photo_library.dart';
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

final storeProvider = Provider<Store>(
  (ref) => isDemo ? MemoryStore() : SqliteStore(),
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
    return AnalysisState(
      features: {
        for (final e in (_cache ?? const <String, PhotoFeatures>{}).entries)
          if (present.contains(e.key)) e.key: e.value,
      },
      total: photos.length,
      done: false,
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
      for (final id in ids)
        Decision(
          photoId: id,
          state: s,
          at: now,
          holdAt: s == DecisionState.hold ? now : null,
        ),
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

DecisionState stateOf(Map<String, Decision> decisions, String id) =>
    decisions[id]?.state ?? DecisionState.undecided;

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

/// 묶음 하나의 추천 정리
final groupPlanProvider = Provider.autoDispose.family<GroupPlan, DayGroup>((
  ref,
  g,
) {
  final features = ref.watch(analysisProvider.select((s) => s.features));
  final decisions = ref.watch(decisionsProvider).value ?? const {};
  return planGroup(g.photos, features, decisions);
});

/// 묶음의 모든 사진을 결정했으면 정리 끝
bool groupDone(DayGroup g, Map<String, Decision> decisions) =>
    g.photos.every((p) {
      final s = stateOf(decisions, p.id);
      return s == DecisionState.keep ||
          s == DecisionState.hold ||
          s == DecisionState.trashed;
    });
