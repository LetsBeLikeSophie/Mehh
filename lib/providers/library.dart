part of '../providers.dart';

// 사진첩·그날의 묶음·장소 이름

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
    _loadedAt = DateTime.now();
    await _read();
    return _state();
  }

  /// 사진첩을 읽어 목록을 바꾼다. 처음 읽기·다시 읽기·새로 고침이 모두 여기를 거친다.
  /// 읽는 사이 휴지통으로 보낸 사진은 읽어 둔 목록에 남아 있을 수 있어 빼 둔다 (UX-84).
  /// 그런 사진이 있었으면 true: 그 사이 페이지가 밀려 빠진 사진이 있을 수 있어 한 번 더 읽는다
  Future<bool> _read() async {
    final lib = ref.read(photoLibraryProvider);
    final removed = _removedWhileLoading = <String>{};
    final List<PhotoMeta> metas;
    final List<PhotoMeta> videos;
    try {
      metas = await lib.loadAll();
      videos = await _loadVideos();
    } finally {
      _removedWhileLoading = null;
    }
    if (!ref.mounted) return false;
    _metas = [
      for (final m in metas)
        if (!removed.contains(m.id)) m,
    ];
    _videos = [
      for (final v in videos)
        if (!removed.contains(v.id)) v,
    ];
    lib.keepOnly({
      for (final m in [..._metas, ..._videos]) m.id,
    });
    Future.microtask(_fillLocations);
    Future.microtask(_reviveRestored);
    return removed.isNotEmpty;
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

  bool _locating = false;
  bool _locateAgain = false;

  /// 위치 채우기는 한 번에 하나만: 돌고 있으면 끝난 뒤 한 번 더 (같은 캐시 파일에 겹쳐 쓰지 않게, 리뷰 10-30 S-2)
  Future<void> _fillLocations() async {
    if (_locating) {
      _locateAgain = true;
      return;
    }
    _locating = true;
    try {
      do {
        _locateAgain = false;
        await _fillLocationsOnce();
      } while (_locateAgain && ref.mounted);
    } finally {
      _locating = false;
    }
  }

  Future<void> _fillLocationsOnce() async {
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

  /// 다시 읽는 중이면, 그 사이 휴지통으로 보낸 사진 id (다 읽은 뒤에도 빼 두려고)
  Set<String>? _removedWhileLoading;

  /// 휴지통으로 보낸 사진을 목록에서 뺀다.
  void removePhotos(Set<String> ids) {
    if (ids.isEmpty) return;
    _removedWhileLoading?.addAll(ids);
    _metas = _metas.where((m) => !ids.contains(m.id)).toList();
    _videos = _videos.where((m) => !ids.contains(m.id)).toList();
    state = AsyncData(_state());
  }

  /// 지금 도는 다시 읽기. 한 번에 하나만 돌고, 도는 중에 다시 읽으라고 하면 끝난 뒤 한 번 더
  /// (리뷰 2026-10-30 S-2: 겹쳐 돌면 먼저 끝난 쪽 결과가 덮이고 보낸 사진이 다시 나타났다)
  Future<void>? _running;
  bool _again = false;

  /// 접근 범위가 바뀌었거나 기록을 지운 뒤: 지금 목록을 보여 준 채로 다시 읽는다.
  /// 처음 읽기가 실패해 목록이 없으면 처음부터
  Future<void> reload() async {
    if (!state.hasValue) {
      ref.invalidateSelf();
      return;
    }
    _loadedAt = DateTime.now();
    if (_running case final running?) {
      _again = true;
      return running;
    }
    await _rereadLoop(_loadedAt);
  }

  /// 지금 바로 갤러리와 다시 맞춘다 (아래로 당겨 새로 고침)
  Future<void> syncNow() => refreshIfStale(Duration.zero);

  /// 마지막으로 불러온 지 [after]가 지났으면, 지금 목록을 보여 준 채로 뒤에서 새로 불러온다
  /// (로딩 화면으로 깜빡이지 않는다). 이미 읽는 중이면 그것으로 충분하다
  Future<void> refreshIfStale(Duration after, {DateTime? now}) async {
    if (!state.hasValue ||
        _running != null ||
        _removedWhileLoading != null || // 처음 읽는 중
        (now ?? DateTime.now()).difference(_loadedAt) < after) {
      return;
    }
    final before = _loadedAt;
    _loadedAt = now ?? DateTime.now();
    await _rereadLoop(before);
  }

  Future<void> _rereadLoop(DateTime before) async {
    final done = Completer<void>();
    _running = done.future;
    try {
      do {
        _again = false;
        try {
          if (await _read()) _again = true;
        } catch (_) {
          // 못 읽었으면 다음에 돌아올 때 다시 시도한다 (지금 목록은 그대로)
          _loadedAt = before;
          return;
        }
        if (!ref.mounted) return;
        state = AsyncData(_state());
      } while (_again);
    } finally {
      _running = null;
      done.complete();
    }
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
