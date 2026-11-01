import 'photo_meta.dart';

/// [day]: 그날의 묶음, [singles]: 사진이 적은 날을 모은 "낱장 사진",
/// [screenshots]: 모든 캡처, [videos]: 카메라로 찍은 동영상(용량 큰 순),
/// [saved]: 카메라 밖에서 온 사진, [savedVideos]: 카메라 밖에서 온 동영상(용량 큰 순)
enum DayGroupKind {
  day,
  singles,
  screenshots,
  videos,
  saved,
  savedVideos;

  /// 앱이 추천하지 않고 직접 고르기만 하는 묶음
  bool get noPicks => this == videos || this == saved || this == savedVideos;

  /// 사진 대신 동영상을 담는 묶음
  bool get isVideo => this == videos || this == savedVideos;
}

/// 그날의 묶음. [photos]는 촬영 시각 오름차순.
class DayGroup {
  const DayGroup({
    required this.id,
    required this.kind,
    required this.photos,
    this.centerLat,
    this.centerLng,
  });

  final String id;
  final DayGroupKind kind;
  final List<PhotoMeta> photos;
  final double? centerLat;
  final double? centerLng;

  DateTime get start => photos.first.takenAt;
  DateTime get end => photos.last.takenAt;
  int get count => photos.length;
  bool get hasCenter => centerLat != null && centerLng != null;

  /// 목록 썸네일로 쓸 사진 (가운데 사진).
  PhotoMeta get cover => photos[photos.length ~/ 2];
}
