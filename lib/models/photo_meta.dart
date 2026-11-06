/// 묶음 계산에 필요한 사진 메타데이터. 플랫폼 타입에 의존하지 않는다.
class PhotoMeta {
  const PhotoMeta({
    required this.id,
    required this.takenAt,
    required this.width,
    required this.height,
    this.lat,
    this.lng,
    this.isScreenshot = false,
    this.modifiedAt = 0,
    this.isFavorite = false,
    this.movedToAlbum = false,
    this.isVideo = false,
    this.durationSec = 0,
    this.sizeBytes = 0,
    this.fromOtherApp = false,
    this.fileName,
    this.capturedAt,
    this.editedFrom,
  });

  /// 동영상 파일 이름 (안드로이드, 편집본 짝 찾기용)
  final String? fileName;

  /// 기기에 적힌 찍은 시각 (동영상, 안드로이드). 편집 앱이 새로 만든 영상은 비어 있다 (2026-11-07 Sophie)
  final DateTime? capturedAt;

  /// 편집 앱(캡컷)이 파일 안에 적어 둔 원본 동영상 id
  final String? editedFrom;

  /// 카메라 폴더 밖에 있다: 다른 앱에서 저장·편집·촬영한 것 (안드로이드, 2026-11-01 Sophie)
  final bool fromOtherApp;

  /// 동영상 (동영상 묶음에만 쓴다, 2026-11-01 Sophie). 그날의 묶음·분석에는 들어가지 않는다
  final bool isVideo;
  final int durationSec;

  /// 파일 크기 (동영상만 채운다)
  final int sizeBytes;

  /// 캡처를 캡처 폴더 밖의 다른 앨범으로 옮겼다 (안드로이드). 남긴다는 신호라 추천하지 않는다
  /// (2026-10-23 Sophie L2-B)
  final bool movedToAlbum;

  /// 갤러리에서 ♥(즐겨찾기)를 눌러 둔 사진. 앱이 정리 추천하지 않는다 (UX 리뷰 2026-10-23)
  final bool isFavorite;

  /// 사진 수정 시각 (초). 분석 캐시 무효화용.
  final int modifiedAt;

  final String id;
  final DateTime takenAt;
  final int width;
  final int height;
  final double? lat;
  final double? lng;
  final bool isScreenshot;

  bool get hasLocation => lat != null && lng != null;

  PhotoMeta withLocation(double? lat, double? lng) => PhotoMeta(
    id: id,
    takenAt: takenAt,
    width: width,
    height: height,
    lat: lat,
    lng: lng,
    isScreenshot: isScreenshot,
    modifiedAt: modifiedAt,
    isFavorite: isFavorite,
    movedToAlbum: movedToAlbum,
    isVideo: isVideo,
    durationSec: durationSec,
    sizeBytes: sizeBytes,
    fromOtherApp: fromOtherApp,
    fileName: fileName,
    capturedAt: capturedAt,
    editedFrom: editedFrom,
  );

  /// 동영상 정보만 바꾼 사본 (크기·기기 정보는 나중에 채운다)
  PhotoMeta withVideo({
    int? sizeBytes,
    bool? fromOtherApp,
    String? fileName,
    DateTime? capturedAt,
    String? editedFrom,
  }) => PhotoMeta(
    id: id,
    takenAt: takenAt,
    width: width,
    height: height,
    lat: lat,
    lng: lng,
    isScreenshot: isScreenshot,
    modifiedAt: modifiedAt,
    isFavorite: isFavorite,
    movedToAlbum: movedToAlbum,
    isVideo: isVideo,
    durationSec: durationSec,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    fromOtherApp: fromOtherApp ?? this.fromOtherApp,
    fileName: fileName ?? this.fileName,
    capturedAt: capturedAt ?? this.capturedAt,
    editedFrom: editedFrom ?? this.editedFrom,
  );

  double get aspect => height == 0 ? 0 : width / height;
}
