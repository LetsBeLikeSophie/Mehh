import 'dart:math' as math;

import '../config/cleanup_config.dart';
import '../models/decision.dart';
import '../models/features.dart';
import '../models/photo_meta.dart';

/// 정리 추천 이유.
/// [junk]: 까맣거나 주머니·렌즈 가림처럼 실수로 찍힌 사진 (한 장뿐이어도 추천)
/// [blurry]·[burst]: 같은 순간을 더 잘 담은 사진이 있을 때만 추천
enum TrashReason { burst, blurry, junk, eyesClosed }

/// 묶음 하나의 추천 정리 결과.
class GroupPlan {
  const GroupPlan({
    required this.bursts,
    required this.best,
    required this.trash,
    this.kept = const {},
    required this.analyzed,
  });

  /// 비슷한 연속 컷 (시간순). 한 장짜리도 포함.
  final List<List<PhotoMeta>> bursts;

  /// 연속 컷마다 베스트 1장 (2장 이상인 연속 컷만)
  final Set<String> best;

  /// 연속 컷에서 남기지만 "베스트"라고 부르지 않는 사진: 품질 차이가 애매해서 가장 나중 컷을 남긴다
  /// (2026-10-24 Sophie: 애매하면 베스트를 붙이지 않는다)
  final Set<String> kept;

  /// 정리 추천 사진과 이유
  final Map<String, TrashReason> trash;

  /// 분석이 끝난 사진 수 (전체보다 적으면 아직 분석 중)
  final int analyzed;

  int count(TrashReason r) => trash.values.where((v) => v == r).length;
}

/// 그날의 묶음에서 돈(코인·Pro)이 드는 추천 장수. 실수 사진(junk)은 늘 무료라 빼고,
/// 이 수가 0이면 묶음은 잠기지 않는다. 정리 화면의 잠금과 Pro 안내의 "잠긴 묶음"이 같이 쓴다 (S-2 2026-10-27)
int paidPickCount(GroupPlan plan) =>
    plan.trash.values.where((r) => r != TrashReason.junk).length;

/// SPEC 6-3, 6-4 (3단계 임시 기준: dHash + 선명도·밝기, ML 없음).
/// [photos]는 시간순. 킵으로 결정한 사진은 추천에서 빠진다.
///
/// 연속 컷마다 정리 줄(toTrash)·휴지통(trashed)에 가지 않은 사진이 최소 1장 남는다:
/// 사용자가 베스트를 정리하면 남은 사진 중에서 베스트를 다시 고른다.
GroupPlan planGroup(
  List<PhotoMeta> photos,
  Map<String, PhotoFeatures> features,
  Map<String, Decision> decisions, {
  CleanupConfig config = const CleanupConfig(),
  Set<TrashReason> muted = const {},
  Set<String> eyesClosed = const {},
}) {
  final bursts = findBursts(photos, features, config: config);
  final best = <String>{};
  final kept = <String>{};
  final trash = <String, TrashReason>{};

  // 추천 후보: 킵·휴지통이 아닌 사진. [추천 보기]로 X(toTrash)가 된 사진도 계속 추천으로 센다
  // (안 그러면 누르자마자 이유 표시·홈 숫자·정확도 기록에서 빠진다, 리뷰 2026-10-22).
  // 예전에 저장된 보류(hold)는 표시 없음으로 본다.
  // ♥(즐겨찾기) 사진은 킵처럼 추천에서 뺀다
  bool open(PhotoMeta p) {
    final s = decisions[p.id]?.state;
    return !p.isFavorite &&
        s != DecisionState.keep &&
        s != DecisionState.trashed;
  }

  bool gone(PhotoMeta p) {
    final s = decisions[p.id]?.state;
    return s == DecisionState.toTrash || s == DecisionState.trashed;
  }

  for (final b in bursts) {
    String? bestId;
    final allAlive = b.where((p) => !gone(p)).toList();
    // 같은 순간에 눈 뜬 컷이 있으면 눈 감은 컷은 남길 후보에서 뺀다 (폰 안 ML Kit, 2026-10-24)
    final eyesOpen = allAlive.where((p) => !eyesClosed.contains(p.id)).toList();
    final hasOpenEyes =
        eyesOpen.isNotEmpty && eyesOpen.length < allAlive.length;
    final alive = hasOpenEyes ? eyesOpen : allAlive;
    if (b.length > 1 && alive.isNotEmpty) {
      final ranked = [
        ...alive,
      ]..sort((x, y) => score(features[y.id]).compareTo(score(features[x.id])));
      final clear =
          ranked.length == 1 ||
          score(features[ranked[0].id]) - score(features[ranked[1].id]) >=
              config.bestMargin;
      if (clear) {
        bestId = ranked.first.id;
        best.add(bestId);
      } else {
        // 차이가 애매하면 가장 나중 컷을 남기고 "베스트"라고 하지 않는다
        bestId = alive
            .reduce((x, y) => x.takenAt.isAfter(y.takenAt) ? x : y)
            .id;
        kept.add(bestId);
      }
    }
    for (final p in b) {
      if (p.id == bestId || !open(p)) continue;
      final f = features[p.id];
      if (f != null && isJunk(f, config)) {
        trash[p.id] = TrashReason.junk;
      } else if (hasOpenEyes && eyesClosed.contains(p.id)) {
        trash[p.id] = TrashReason.eyesClosed;
      } else if (bestId == null) {
        // 그 순간의 유일한 사진은 흔들렸어도 건드리지 않는다
        continue;
      } else if (f != null && f.sharpness < config.blurrySharpness) {
        trash[p.id] = TrashReason.blurry;
      } else {
        trash[p.id] = TrashReason.burst;
      }
    }
  }
  // 사용자가 자주 되돌린 이유는 빼기 (취향 학습)
  trash.removeWhere((_, r) => muted.contains(r));
  return GroupPlan(
    bursts: bursts,
    best: best,
    kept: kept,
    trash: trash,
    analyzed: photos.where((p) => features.containsKey(p.id)).length,
  );
}

enum ShotReason { old, repeat }

/// 캡처 추천 (무료, [추천 보기]로 X): 연달아 찍은 비슷한 캡처는 마지막 한 장만 남기고,
/// 그 밖에는 [CleanupConfig.oldScreenshot]보다 오래된 캡처. 킵·휴지통으로 정한 캡처는 뺀다.
/// "연달아 찍음"은 **다음의 남는 장**(정리·휴지통이 아닌 장)과 비교한다: 다음 장을 이미 지웠거나
/// X를 쳤으면 이 장이 마지막이 되어 한 화면이 통째로 사라지지 않는다 (시니어 리뷰 2026-10-23 S-7).
/// [shots]는 시간순.
Map<String, ShotReason> planScreenshots(
  List<PhotoMeta> shots,
  Map<String, PhotoFeatures> features,
  Map<String, Decision> decisions, {
  required DateTime now,
  CleanupConfig config = const CleanupConfig(),
}) {
  DecisionState? stateOf(PhotoMeta p) => decisions[p.id]?.state;
  final live = [
    for (final p in shots)
      if (stateOf(p) != DecisionState.trashed) p,
  ];
  bool gone(PhotoMeta p) => stateOf(p) == DecisionState.toTrash;

  final out = <String, ShotReason>{};
  for (var i = 0; i < live.length; i++) {
    final p = live[i];
    // 킵·♥(즐겨찾기)·다른 앨범으로 옮긴 캡처는 추천하지 않는다
    if (stateOf(p) == DecisionState.keep || p.isFavorite || p.movedToAlbum) {
      continue;
    }
    // 다음의 남는 장이 같은 화면을 곧이어 찍은 것이면 이것은 지난 장
    for (var j = i + 1; j < live.length; j++) {
      final q = live[j];
      if (gone(q)) continue;
      if (_sameShot(p, q, features, config, steps: j - i)) {
        out[p.id] = ShotReason.repeat;
      }
      break;
    }
    if (out.containsKey(p.id)) continue;
    if (now.difference(p.takenAt) > config.oldScreenshot) {
      out[p.id] = ShotReason.old;
    }
  }
  return out;
}

/// 연달아 찍은 같은 화면 캡처 묶음 (2장 이상). 통째로 휴지통으로 가면 한 번 묻는다.
/// 마지막 장까지 오래된 묶음은 앱이 통째로 추천하므로 넣지 않는다 (UX 리뷰 2026-10-23).
List<List<String>> screenshotRuns(
  List<PhotoMeta> shots,
  Map<String, PhotoFeatures> features,
  Map<String, Decision> decisions, {
  required DateTime now,
  CleanupConfig config = const CleanupConfig(),
}) {
  final live = [
    for (final p in shots)
      if (decisions[p.id]?.state != DecisionState.trashed) p,
  ];
  final runs = <List<PhotoMeta>>[];
  var cur = <PhotoMeta>[];
  for (var i = 0; i < live.length; i++) {
    if (i > 0 && _sameShot(live[i - 1], live[i], features, config)) {
      cur.add(live[i]);
    } else {
      if (cur.length > 1) runs.add(cur);
      cur = [live[i]];
    }
  }
  if (cur.length > 1) runs.add(cur);
  return [
    for (final r in runs)
      if (now.difference(r.last.takenAt) <= config.oldScreenshot)
        [for (final p in r) p.id],
  ];
}

bool _sameShot(
  PhotoMeta p,
  PhotoMeta q,
  Map<String, PhotoFeatures> features,
  CleanupConfig config, {
  int steps = 1,
}) {
  final fp = features[p.id], fq = features[q.id];
  return fp != null &&
      fq != null &&
      q.takenAt.difference(p.takenAt) <= config.burstMaxGap * steps &&
      fp.hammingTo(fq) <= config.burstMaxHamming;
}

/// 까만 사진, 주머니 속·렌즈를 가린 사진처럼 실수로 찍힌 사진
bool isJunk(PhotoFeatures f, CleanupConfig c) =>
    f.brightness < c.darkBrightness ||
    (f.brightness < c.pocketBrightness &&
        f.contrast < c.pocketContrast &&
        f.sharpness < c.blurrySharpness * 3);

/// 같은 묶음 안에서 촬영 간격이 짧고 비슷한 사진끼리 연속 컷으로 묶는다.
List<List<PhotoMeta>> findBursts(
  List<PhotoMeta> photos,
  Map<String, PhotoFeatures> features, {
  CleanupConfig config = const CleanupConfig(),
}) {
  final bursts = <List<PhotoMeta>>[];
  for (final p in photos) {
    final cur = bursts.isEmpty ? null : bursts.last;
    final prev = cur?.last;
    final fp = features[p.id], fq = prev == null ? null : features[prev.id];
    final joins =
        prev != null &&
        fp != null &&
        fq != null &&
        p.takenAt.difference(prev.takenAt) <= config.burstMaxGap &&
        fp.hammingTo(fq) <= config.burstMaxHamming;
    if (joins) {
      cur!.add(p);
    } else {
      bursts.add([p]);
    }
  }
  return bursts;
}

/// 베스트 컷 점수: 선명할수록, 노출이 적당할수록 높다.
double score(PhotoFeatures? f) {
  if (f == null) return double.negativeInfinity;
  final sharp = math.log(1 + f.sharpness);
  final b = f.brightness;
  final exposure = b < 50
      ? (50 - b) / 50
      : b > 215
      ? (b - 215) / 40
      : 0.0;
  return sharp - 2 * exposure;
}

/// 베스트로 고른 이유 (화면 문구는 UI에서 언어별로)
enum BestReason { sharp, exposure }

/// 눈에 띄는 차이만 이유로 쓴다: 다른 컷보다 확실히 선명할 때 "선명", 다른 컷 중에 너무 어둡거나
/// 밝은 게 있을 때만 "노출" (2026-10-24 Sophie: 다 비슷한데 "초점 선명"이라 하면 믿을 수 없다)
List<BestReason> bestReasons(PhotoFeatures? f, List<PhotoFeatures?> others) {
  if (f == null) return const [];
  final rest = others.whereType<PhotoFeatures>().where((o) => o.id != f.id);
  final sharper = rest.every((o) => f.sharpness >= o.sharpness * 1.3);
  bool badExposure(PhotoFeatures o) => o.brightness < 50 || o.brightness > 215;
  return [
    if (sharper && rest.isNotEmpty) BestReason.sharp,
    if (!badExposure(f) && rest.any(badExposure)) BestReason.exposure,
  ];
}
