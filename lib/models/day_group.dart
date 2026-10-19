import 'photo_meta.dart';

enum DayGroupKind { day, screenshots }

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
