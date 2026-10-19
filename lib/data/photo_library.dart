import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

import '../models/photo_meta.dart';
import 'json_cache.dart';

const _permissionOption = PermissionRequestOption(
  androidPermission: AndroidPermission(
    type: RequestType.image,
    mediaLocation: true,
  ),
);

/// 기기 사진첩 접근. 영상은 다루지 않는다.
class PhotoLibrary {
  final _locationCache = JsonCache('locations.json');

  /// id → 플랫폼 사진 객체 (썸네일 표시용)
  final Map<String, AssetEntity> entities = {};

  Future<PermissionState> permissionState() =>
      PhotoManager.getPermissionState(requestOption: _permissionOption);

  Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend(requestOption: _permissionOption);

  Future<void> openSettings() => PhotoManager.openSetting();

  /// 일부만 허용한 상태에서 사진 선택 화면을 다시 띄운다.
  Future<void> presentLimited() =>
      PhotoManager.presentLimited(type: RequestType.image);

  /// 모든 사진의 메타데이터. 위치는 캐시에 있는 것만 채운다.
  Future<List<PhotoMeta>> loadAll() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) return [];
    final all = paths.first;
    final total = await all.assetCountAsync;
    final cached = await _locationCache.read();

    entities.clear();
    final metas = <PhotoMeta>[];
    const page = 1000;
    for (var start = 0; start < total; start += page) {
      final list = await all.getAssetListRange(start: start, end: start + page);
      for (final e in list) {
        entities[e.id] = e;
        double? lat = e.latitude, lng = e.longitude;
        if (!_valid(lat, lng)) {
          final c = cached[e.id];
          lat = c is List ? (c[0] as num).toDouble() : null;
          lng = c is List ? (c[1] as num).toDouble() : null;
        }
        metas.add(
          PhotoMeta(
            id: e.id,
            takenAt: e.createDateTime,
            width: e.width,
            height: e.height,
            lat: lat,
            lng: lng,
            isScreenshot: _isScreenshot(e),
          ),
        );
      }
    }
    return metas;
  }

  /// 아직 위치를 확인하지 않은 사진들의 EXIF 위치를 읽어 캐시에 저장한다.
  /// 안드로이드 10+에서는 목록 조회에 위치가 오지 않아 한 장씩 읽어야 한다.
  /// 반환: 새로 위치를 찾은 사진 id → (lat, lng)
  Future<Map<String, (double, double)>> fillLocations(
    List<PhotoMeta> metas, {
    void Function(int done, int total)? onProgress,
  }) async {
    final cached = await _locationCache.read();
    final todo = metas
        .where((m) => !m.hasLocation && !cached.containsKey(m.id))
        .map((m) => m.id)
        .toList();
    final found = <String, (double, double)>{};
    if (todo.isEmpty) return found;

    const batch = 16;
    for (var i = 0; i < todo.length; i += batch) {
      final ids = todo.skip(i).take(batch);
      await Future.wait(
        ids.map((id) async {
          LatLng? ll;
          try {
            ll = await entities[id]?.latlngAsync();
          } catch (_) {}
          if (ll != null && _valid(ll.latitude, ll.longitude)) {
            cached[id] = [ll.latitude, ll.longitude];
            found[id] = (ll.latitude, ll.longitude);
          } else {
            cached[id] = null; // 위치 없음도 기록해 다시 읽지 않는다
          }
        }),
      );
      final done = (i + batch).clamp(0, todo.length);
      onProgress?.call(done, todo.length);
      if (done % 800 < batch) await _locationCache.write(cached);
    }
    await _locationCache.write(cached);
    return found;
  }

  static bool _valid(double? lat, double? lng) =>
      lat != null && lng != null && !(lat == 0 && lng == 0);

  static bool _isScreenshot(AssetEntity e) {
    if (Platform.isIOS) {
      // PHAssetMediaSubtypePhotoScreenshot
      return e.subtype & 4 != 0;
    }
    final path = (e.relativePath ?? '').toLowerCase();
    final title = (e.title ?? '').toLowerCase();
    return path.contains('screenshot') || title.startsWith('screenshot');
  }
}
