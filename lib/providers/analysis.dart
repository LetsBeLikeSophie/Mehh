part of '../providers.dart';

// 사진 분석 (해시·선명도·밝기)

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
