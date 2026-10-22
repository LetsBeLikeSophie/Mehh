import '../config/cleanup_config.dart';
import '../models/pick.dart';
import 'recommend.dart';

/// [휴지통으로]를 누른 순간의 기록을 만든다 (SPEC 6-8).
/// 추천했거나, 보냈거나, 베스트였던 사진만 남긴다 (나머지는 셀 게 없다).
List<PickRecord> pickRecords({
  required DateTime at,
  required String kind,
  required Iterable<String> shown,
  required Set<String> sent,
  required Set<String> suggested,
  required Map<String, String> tags,
}) => [
  for (final id in shown)
    if (suggested.contains(id) || sent.contains(id) || tags[id] == 'best')
      PickRecord(
        at: at,
        kind: kind,
        tag: tags[id],
        suggested: suggested.contains(id),
        sent: sent.contains(id),
      ),
];

/// 자주 되돌린 추천 이유 (취향 학습, [CleanupConfig.learnMinSamples]).
/// 표시 이름(burst·blurry·junk) → 정리 추천 이유.
Set<TrashReason> mutedReasons(
  PickStats s, {
  CleanupConfig config = const CleanupConfig(),
}) => {
  for (final (tag, reason) in const [
    ('burst', TrashReason.burst),
    ('blurry', TrashReason.blurry),
    ('junk', TrashReason.junk),
  ])
    if (s.byTag[tag] case (final accepted, final total)
        when total >= config.learnMinSamples &&
            accepted / total < config.learnMinAcceptRate)
      reason,
};

/// 추천 정확도 요약
class PickStats {
  const PickStats({
    required this.sends,
    required this.suggested,
    required this.accepted,
    required this.added,
    required this.best,
    required this.bestKept,
    required this.byTag,
  });

  factory PickStats.of(List<PickRecord> list) {
    final byTag = <String, (int, int)>{};
    var suggested = 0, accepted = 0, added = 0, best = 0, bestKept = 0;
    for (final p in list) {
      if (p.suggested) {
        suggested++;
        if (p.sent) accepted++;
        final t = p.tag ?? '-';
        final (a, n) = byTag[t] ?? (0, 0);
        byTag[t] = (a + (p.sent ? 1 : 0), n + 1);
      } else if (p.tag == 'best') {
        best++;
        if (!p.sent) bestKept++;
      } else if (p.sent) {
        added++;
      }
    }
    return PickStats(
      sends: {for (final p in list) p.at}.length,
      suggested: suggested,
      accepted: accepted,
      added: added,
      best: best,
      bestKept: bestKept,
      byTag: byTag,
    );
  }

  /// [휴지통으로]를 누른 횟수
  final int sends;

  /// 앱이 추천한 사진 / 그중 실제로 보낸 사진
  final int suggested;
  final int accepted;

  /// 추천하지 않았는데 사용자가 직접 골라 보낸 사진 (앱이 놓친 것)
  final int added;

  /// 베스트로 고른 사진 / 그중 사용자도 남긴 사진
  final int best;
  final int bestKept;

  /// 표시별 (보낸 수, 추천 수)
  final Map<String, (int, int)> byTag;

  /// 추천을 받아들인 비율 (0~1). 추천이 없으면 null
  double? get acceptRate => suggested == 0 ? null : accepted / suggested;

  /// 사용자가 보낸 것 중 앱이 미리 고른 비율 (0~1)
  double? get coverage =>
      accepted + added == 0 ? null : accepted / (accepted + added);

  double? get bestRate => best == 0 ? null : bestKept / best;
}
