import '../models/decision.dart';
import '../models/features.dart';
import '../models/pick.dart';

/// 기기 안에만 저장하는 데이터 (분석 결과, 결정, 열람 기록, 비운 용량).
abstract class Store {
  Future<Map<String, PhotoFeatures>> loadFeatures();
  Future<void> saveFeatures(List<PhotoFeatures> list);

  Future<Map<String, Decision>> loadDecisions();

  /// 결정을 저장하고 로그에도 남긴다 (취향 학습용, SPEC 6-7).
  Future<void> saveDecisions(List<Decision> list);

  Future<Map<String, ViewRecord>> loadViews();
  Future<void> recordView(String photoId, DateTime at);

  /// 'yyyy-MM' 별로 비운 용량(바이트)을 누적한다.
  Future<void> addFreedBytes(String month, int bytes);
  Future<int> freedBytes(String month);

  /// 추천 정확도 기록 (설정의 숨은 화면용)
  Future<void> addPicks(List<PickRecord> list);
  Future<List<PickRecord>> loadPicks();

  /// 잠긴 채로(추천을 열지 않고) 직접 정리해 휴지통으로 보낸 묶음의 남은 사진.
  /// 이 사진이 든 잠긴 묶음은 "다 봤어요"로 본다 (2026-10-22 Sophie R3-A)
  Future<void> addSeen(Iterable<String> photoIds);
  Future<Set<String>> loadSeen();

  /// 이 폰에 남긴 모든 기록을 지운다 (분석 결과, 결정, 열람, 비운 용량).
  Future<void> clearAll();
}

String monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// 웹 미리보기·테스트용. 앱을 끄면 사라진다.
class MemoryStore implements Store {
  final features = <String, PhotoFeatures>{};
  final decisions = <String, Decision>{};
  final log = <Decision>[];
  final views = <String, ViewRecord>{};
  final freed = <String, int>{};
  final picks = <PickRecord>[];
  final seen = <String>{};

  @override
  Future<void> addSeen(Iterable<String> photoIds) async =>
      seen.addAll(photoIds);

  @override
  Future<Set<String>> loadSeen() async => {...seen};

  @override
  Future<void> addPicks(List<PickRecord> list) async => picks.addAll(list);

  @override
  Future<List<PickRecord>> loadPicks() async => [...picks];

  @override
  Future<Map<String, PhotoFeatures>> loadFeatures() async => {...features};

  @override
  Future<void> saveFeatures(List<PhotoFeatures> list) async {
    for (final f in list) {
      features[f.id] = f;
    }
  }

  @override
  Future<Map<String, Decision>> loadDecisions() async => {...decisions};

  @override
  Future<void> saveDecisions(List<Decision> list) async {
    for (final d in list) {
      decisions[d.photoId] = d;
      log.add(d);
    }
  }

  @override
  Future<Map<String, ViewRecord>> loadViews() async => {...views};

  @override
  Future<void> recordView(String photoId, DateTime at) async {
    final v = views[photoId];
    views[photoId] = ViewRecord(count: (v?.count ?? 0) + 1, lastAt: at);
  }

  @override
  Future<void> addFreedBytes(String month, int bytes) async {
    freed[month] = (freed[month] ?? 0) + bytes;
  }

  @override
  Future<int> freedBytes(String month) async => freed[month] ?? 0;

  @override
  Future<void> clearAll() async {
    features.clear();
    decisions.clear();
    log.clear();
    views.clear();
    freed.clear();
    picks.clear();
    seen.clear();
  }
}
