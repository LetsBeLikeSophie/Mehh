import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import 'data/demo.dart';
import 'data/photo_library.dart';
import 'data/place_namer.dart';
import 'logic/day_grouper.dart';
import 'models/day_group.dart';
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

class LibraryState {
  const LibraryState({required this.groups, this.locating});

  final List<DayGroup> groups;

  /// 위치를 읽는 중이면 (완료, 전체), 아니면 null
  final (int, int)? locating;

  int get dayGroupCount =>
      groups.where((g) => g.kind == DayGroupKind.day).length;

  LibraryState copyWith({(int, int)? locating}) =>
      LibraryState(groups: groups, locating: locating ?? this.locating);
}

/// 사진 불러오기 → 묶음. 위치는 백그라운드에서 채우고 다시 묶는다.
class LibraryNotifier extends AsyncNotifier<LibraryState> {
  List<PhotoMeta> _metas = [];

  @override
  Future<LibraryState> build() async {
    final lib = ref.read(photoLibraryProvider);
    _metas = await lib.loadAll();
    Future.microtask(_fillLocations);
    return LibraryState(groups: groupPhotos(_metas));
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
    state = AsyncData(LibraryState(groups: groupPhotos(_metas)));
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
