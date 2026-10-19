import 'dart:math' as math;

import '../config/grouping_config.dart';
import '../models/day_group.dart';
import '../models/photo_meta.dart';

/// 사진을 그날의 묶음으로 나눈다. 결과는 최신 묶음이 먼저.
List<DayGroup> groupPhotos(
  Iterable<PhotoMeta> photos, {
  GroupingConfig config = const GroupingConfig(),
}) {
  final sorted = photos.toList()
    ..sort((a, b) => a.takenAt.compareTo(b.takenAt));

  final groups = <DayGroup>[];
  final shotsByMonth = <String, List<PhotoMeta>>{};
  var current = <PhotoMeta>[];

  void close() {
    if (current.isEmpty) return;
    groups.add(_dayGroup(current));
    current = [];
  }

  for (final p in sorted) {
    if (p.isScreenshot) {
      final key =
          '${p.takenAt.year}-${p.takenAt.month.toString().padLeft(2, '0')}';
      shotsByMonth.putIfAbsent(key, () => []).add(p);
      continue;
    }
    if (current.isNotEmpty && _startsNewGroup(current.last, p, config)) {
      close();
    }
    current.add(p);
  }
  close();

  for (final entry in shotsByMonth.entries) {
    groups.add(
      DayGroup(
        id: 'shots-${entry.key}',
        kind: DayGroupKind.screenshots,
        photos: entry.value,
      ),
    );
  }

  groups.sort((a, b) => b.end.compareTo(a.end));
  return groups;
}

bool _startsNewGroup(PhotoMeta prev, PhotoMeta next, GroupingConfig config) {
  final gap = next.takenAt.difference(prev.takenAt);
  if (gap >= config.maxGap) return true;
  if (prev.hasLocation &&
      next.hasLocation &&
      distanceKm(prev.lat!, prev.lng!, next.lat!, next.lng!) >=
          config.maxDistanceKm) {
    return true;
  }
  if (!_sameDay(prev.takenAt, next.takenAt) && gap >= config.dayChangeGap) {
    return true;
  }
  return false;
}

DayGroup _dayGroup(List<PhotoMeta> photos) {
  final located = photos.where((p) => p.hasLocation).toList();
  double? lat, lng;
  if (located.isNotEmpty) {
    lat = located.map((p) => p.lat!).reduce((a, b) => a + b) / located.length;
    lng = located.map((p) => p.lng!).reduce((a, b) => a + b) / located.length;
  }
  return DayGroup(
    id: 'day-${photos.first.id}',
    kind: DayGroupKind.day,
    photos: photos,
    centerLat: lat,
    centerLng: lng,
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 두 좌표 사이 거리 (km, 하버사인).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}
