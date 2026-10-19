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
  });

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
  );

  double get aspect => height == 0 ? 0 : width / height;
}
