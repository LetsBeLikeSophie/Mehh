import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../logic/image_analysis.dart';
import '../logic/screen_detect.dart';
import '../models/features.dart';
import '../models/photo_meta.dart';
import 'json_cache.dart';

const _permissionOption = PermissionRequestOption(
  androidPermission: AndroidPermission(
    // 큰 동영상 정리를 위해 동영상도 (2026-10-24 Sophie)
    type: RequestType.common,
    mediaLocation: true,
  ),
);

/// 기기 사진첩 접근. 동영상은 "큰 동영상"에만 쓴다([loadVideos]).
class PhotoLibrary {
  final _locationCache = JsonCache('locations.json');

  /// id → 플랫폼 사진 객체 (썸네일 표시용)
  final Map<String, AssetEntity> entities = {};

  Future<PermissionState> permissionState() =>
      PhotoManager.getPermissionState(requestOption: _permissionOption);

  Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend(requestOption: _permissionOption);

  Future<void> openSettings() => PhotoManager.openSetting();

  /// 위치 캐시 지우기
  Future<void> clearCache() => _locationCache.delete();

  /// 일부만 허용한 상태에서 사진 선택 화면을 다시 띄운다.
  Future<void> presentLimited() =>
      PhotoManager.presentLimited(type: RequestType.common);

  /// 모든 동영상 (크기는 [sizes]에서, 없으면 0). [loadAll] 다음에 부른다(사진 목록을 지우지 않는다)
  Future<List<PhotoMeta>> loadVideos(Map<String, int> sizes) async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
    );
    if (paths.isEmpty) return [];
    final all = paths.first;
    final total = await all.assetCountAsync;
    final out = <PhotoMeta>[];
    const page = 500;
    for (var start = 0; start < total; start += page) {
      for (final e in await all.getAssetListRange(
        start: start,
        end: start + page,
      )) {
        entities[e.id] = e;
        out.add(
          PhotoMeta(
            id: e.id,
            takenAt: e.createDateTime,
            width: e.width,
            height: e.height,
            isVideo: true,
            durationSec: e.duration,
            sizeBytes: sizes[e.id] ?? 0,
            isFavorite: e.isFavorite,
          ),
        );
      }
    }
    return out;
  }

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
            modifiedAt: e.modifiedDateSecond ?? 0,
            isFavorite: e.isFavorite,
            movedToAlbum: _movedToAlbum(e),
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

  /// 썸네일(128px)로 분석한다. 썸네일은 여러 장씩 받아 백그라운드에서 계산.
  /// [onBatch]로 조금씩 결과를 넘긴다.
  Future<void> analyze(
    List<PhotoMeta> metas, {
    required Future<void> Function(List<PhotoFeatures>) onBatch,
    bool Function()? cancelled,
  }) async {
    const batch = 24;
    for (var i = 0; i < metas.length; i += batch) {
      if (cancelled?.call() ?? false) return;
      final part = metas.skip(i).take(batch).toList();
      final inputs = <AnalysisInput>[];
      await Future.wait(
        part.map((m) async {
          try {
            final bytes = await entities[m.id]?.thumbnailDataWithSize(
              const ThumbnailSize.square(128),
              quality: 90,
            );
            if (bytes != null) {
              inputs.add(AnalysisInput(m.id, m.modifiedAt, bytes));
            }
          } catch (_) {}
        }),
      );
      final result = await compute(analyzeBatch, inputs);
      await onBatch(result);
    }
  }

  /// 파일 크기 (바이트). 실패하면 0. 한 번 읽은 크기는 기억한다 (막대가 자주 다시 묻는다)
  Future<Map<String, int>> fileSizes(Iterable<String> ids) async {
    final out = <String, int>{};
    await Future.wait(
      ids.map((id) async {
        if (_sizes[id] case final n?) {
          out[id] = n;
          return;
        }
        try {
          out[id] = _sizes[id] = await entities[id]?.fileSize ?? 0;
        } catch (_) {
          out[id] = 0;
        }
      }),
    );
    return out;
  }

  final _sizes = <String, int>{};

  /// 휴대폰 휴지통으로 보낸다. 여러 장을 한 번의 확인 창으로.
  /// 안드로이드는 11 이상만 지원해서(minSdk 30) 항상 휴지통이 있다.
  /// 실패하면 영구 삭제로 넘어가지 않고 예외를 그대로 던진다.
  /// 반환: 실제로 옮긴 사진 id (사용자가 취소하면 빈 목록)
  Future<List<String>> trash(List<String> ids) async {
    final list = [for (final id in ids) ?entities[id]];
    if (list.isEmpty) return [];
    if (Platform.isAndroid) {
      return PhotoManager.editor.android.moveToTrash(list);
    }
    // iOS는 삭제하면 "최근 삭제된 항목"으로 간다.
    return PhotoManager.editor.deleteWithIds(ids);
  }

  static bool _valid(double? lat, double? lng) =>
      lat != null && lng != null && !(lat == 0 && lng == 0);

  /// 이름은 캡처인데 캡처 폴더 밖에 있다 = 사용자가 다른 앨범으로 옮긴 캡처 (안드로이드만)
  static bool _movedToAlbum(AssetEntity e) {
    if (Platform.isIOS) return false;
    final path = (e.relativePath ?? '').toLowerCase();
    final title = (e.title ?? '').toLowerCase();
    return title.startsWith('screenshot') && !path.contains('screenshot');
  }

  static bool _isScreenshot(AssetEntity e) {
    if (Platform.isIOS) {
      // PHAssetMediaSubtypePhotoScreenshot
      return e.subtype & 4 != 0;
    }
    return looksLikeScreen(
      path: e.relativePath ?? '',
      title: e.title ?? '',
      width: e.width,
      height: e.height,
    );
  }
}
