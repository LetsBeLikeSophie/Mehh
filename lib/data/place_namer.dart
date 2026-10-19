import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';

import 'json_cache.dart';

/// 좌표 → 짧은 장소 이름. 플랫폼 지오코더를 쓰고 결과는 기기에 캐시한다.
/// 좌표가 OS/구글 서비스로 전달될 수 있음 (개인정보처리방침에 명시).
class PlaceNamer {
  PlaceNamer({this.locale});

  final Locale? locale;
  late final _geocoding = Geocoding();
  final _cache = JsonCache('places.json');
  Map<String, dynamic>? _memory;
  final _inflight = <String, Future<String?>>{};

  /// 약 100m 단위로 묶어서 캐시한다.
  static String keyOf(double lat, double lng) =>
      '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';

  Future<String?> nameOf(double lat, double lng) async {
    final key = keyOf(lat, lng);
    final mem = _memory ??= await _cache.read();
    if (mem.containsKey(key)) return mem[key] as String?;
    return _inflight[key] ??= _lookup(key, lat, lng).whenComplete(() {
      _inflight.remove(key);
    });
  }

  Future<String?> _lookup(String key, double lat, double lng) async {
    String? name;
    try {
      final marks = await _geocoding.placemarkFromCoordinates(
        lat,
        lng,
        locale: locale,
      );
      if (marks.isNotEmpty) name = pickName(marks.first);
    } catch (_) {
      // 오프라인 등: 캐시하지 않고 다음에 다시 시도
      return null;
    }
    _memory![key] = name;
    await _cache.write(_memory!);
    return name;
  }

  /// 장소명 > 동 > 구 순으로 가장 구체적인 이름.
  static String? pickName(Placemark p) {
    String? clean(String? s) =>
        (s == null || s.trim().isEmpty) ? null : s.trim();
    final area = [
      p.subLocality,
      p.thoroughfare,
      p.locality,
      p.subAdministrativeArea,
    ].map(clean).whereType<String>().toSet();
    final name = clean(p.name);
    // 안드로이드는 name에 번지수나 전체 주소가 오는 경우가 많다
    final looksLikeAddress =
        name != null &&
        (RegExp(r'\d').hasMatch(name) ||
            area.contains(name) ||
            name.length > 20);
    if (name != null && !looksLikeAddress) return name;
    return clean(p.subLocality) ??
        clean(p.thoroughfare) ??
        clean(p.locality) ??
        clean(p.subAdministrativeArea) ??
        clean(p.administrativeArea);
  }
}
