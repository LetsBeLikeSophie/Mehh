import 'dart:math' as math;

import '../config/cleanup_config.dart';
import '../models/decision.dart';
import '../models/features.dart';
import '../models/photo_meta.dart';

/// 정리 추천 이유.
/// [junk]: 까맣거나 주머니·렌즈 가림처럼 실수로 찍힌 사진 (한 장뿐이어도 추천)
/// [blurry]·[burst]: 같은 순간을 더 잘 담은 사진이 있을 때만 추천
enum TrashReason { burst, blurry, junk }

/// 묶음 하나의 추천 정리 결과.
class GroupPlan {
  const GroupPlan({
    required this.bursts,
    required this.best,
    required this.trash,
    required this.analyzed,
  });

  /// 비슷한 연속 컷 (시간순). 한 장짜리도 포함.
  final List<List<PhotoMeta>> bursts;

  /// 연속 컷마다 베스트 1장 (2장 이상인 연속 컷만)
  final Set<String> best;

  /// 정리 추천 사진과 이유
  final Map<String, TrashReason> trash;

  /// 분석이 끝난 사진 수 (전체보다 적으면 아직 분석 중)
  final int analyzed;

  int count(TrashReason r) => trash.values.where((v) => v == r).length;
}

/// SPEC 6-3, 6-4 (3단계 임시 기준: dHash + 선명도·밝기, ML 없음).
/// [photos]는 시간순. keep/hold로 결정한 사진은 추천에서 빠진다.
///
/// 연속 컷마다 정리 줄(toTrash)·휴지통(trashed)에 가지 않은 사진이 최소 1장 남는다:
/// 사용자가 베스트를 정리하면 남은 사진 중에서 베스트를 다시 고른다.
GroupPlan planGroup(
  List<PhotoMeta> photos,
  Map<String, PhotoFeatures> features,
  Map<String, Decision> decisions, {
  CleanupConfig config = const CleanupConfig(),
}) {
  final bursts = findBursts(photos, features, config: config);
  final best = <String>{};
  final trash = <String, TrashReason>{};

  bool open(PhotoMeta p) =>
      (decisions[p.id]?.state ?? DecisionState.undecided) ==
      DecisionState.undecided;

  bool gone(PhotoMeta p) {
    final s = decisions[p.id]?.state;
    return s == DecisionState.toTrash || s == DecisionState.trashed;
  }

  for (final b in bursts) {
    String? bestId;
    final alive = b.where((p) => !gone(p)).toList();
    if (b.length > 1 && alive.isNotEmpty) {
      bestId = alive
          .reduce(
            (x, y) => score(features[x.id]) >= score(features[y.id]) ? x : y,
          )
          .id;
      best.add(bestId);
    }
    for (final p in b) {
      if (p.id == bestId || !open(p)) continue;
      final f = features[p.id];
      if (f != null && isJunk(f, config)) {
        trash[p.id] = TrashReason.junk;
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
  return GroupPlan(
    bursts: bursts,
    best: best,
    trash: trash,
    analyzed: photos.where((p) => features.containsKey(p.id)).length,
  );
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

/// 베스트 추천 이유 한 줄 ("초점 선명 · 밝기 적당")
String bestReason(PhotoFeatures? f, List<PhotoFeatures?> others) {
  if (f == null) return '';
  final parts = <String>[];
  final sharper = others.whereType<PhotoFeatures>().every(
    (o) => o.id == f.id || f.sharpness >= o.sharpness,
  );
  if (sharper) parts.add('초점 선명');
  if (f.brightness >= 50 && f.brightness <= 215) parts.add('밝기 적당');
  return parts.join(' · ');
}

/// "흔들린 사진 21장, 비슷한 연속 컷 117장"
String trashSummary(GroupPlan plan) {
  final parts = <String>[];
  final blurry = plan.count(TrashReason.blurry);
  final junk = plan.count(TrashReason.junk);
  final burst = plan.count(TrashReason.burst);
  if (junk > 0) parts.add('실수로 찍힌 사진 $junk장');
  if (blurry > 0) parts.add('더 선명한 컷이 있는 흔들린 사진 $blurry장');
  if (burst > 0) parts.add('비슷한 연속 컷 $burst장');
  return parts.join(', ');
}
