import 'photo_meta.dart';

/// [day]: 그날의 묶음, [singles]: 사진이 적은 날을 모은 "낱장 사진",
/// [screenshots]: 모든 캡처,
/// [saved]: 카메라 밖에서 온 사진.
/// [videos]: 모든 동영상 하나 (2026-11-08 Sophie: 찍은·받은·편집 세 줄을 합침, 안에서 나눔)
enum DayGroupKind {
  day,
  singles,
  screenshots,
  videos,
  saved;

  /// 앱이 추천하지 않고 직접 고르기만 하는 묶음
  bool get noPicks => this == videos || this == saved;

  /// 사진 대신 동영상을 담는 묶음
  bool get isVideo => this == videos;
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
