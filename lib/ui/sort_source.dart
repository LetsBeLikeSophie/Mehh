import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../logic/duplicates.dart';
import '../logic/format.dart';
import '../logic/recommend.dart';
import '../models/day_group.dart';
import '../models/decision.dart';
import '../models/photo_meta.dart';
import '../providers.dart';

/// 정리 화면에 들어가는 것: 그날의 묶음, 낱장 사진, 캡처, 똑같은 사진
enum SortKind { day, singles, screenshots, duplicates }

/// 사진 위 짧은 표시의 종류 (문구는 [tagText]·[noteText]에서 언어별로)
enum PhotoTag { best, burst, blurry, junk, original, duplicate }

/// 정리 화면(그리드)과 크게 보기가 함께 쓰는 사진 목록과 앱 추천
class SortSource {
  const SortSource({
    required this.photos,
    this.suggested = const {},
    this.tags = const {},
    this.bestReasons = const {},
    this.plan,
    this.analyzing = false,
    this.units = const [],
    this.locked = 0,
  });

  /// 보여줄 순서 (휴지통으로 간 사진 포함, 화면에서 거른다)
  final List<PhotoMeta> photos;

  /// 앱이 정리 추천한 사진 (사용자가 바꾸기 전까지 X가 켜져 있다)
  final Set<String> suggested;

  /// 그리드 칸·크게 보기에 붙일 표시
  final Map<String, PhotoTag> tags;

  /// 베스트로 고른 이유 ("초점 선명 · 밝기 적당")
  final Map<String, List<BestReason>> bestReasons;

  /// 묶음 추천 (요약 박스용). 중복·캡처는 null
  final GroupPlan? plan;
  final bool analyzing;

  /// 연속 컷·중복 묶음 (2장 이상). 통째로 휴지통으로 가면 한 번 묻는다.
  final List<List<String>> units;

  /// 무료 묶음·Pro로 열기 전이라 가려 둔 정리 추천 장수 (그날의 묶음만, SPEC 9장).
  /// 0이면 열려 있거나 추천이 없다.
  final int locked;
}

String sortTitle(SortKind kind, DayGroup? g, String? place, L10n l) =>
    switch (kind) {
      SortKind.duplicates => l.duplicatesTitle,
      _ => groupTitle(g!, l, place: place),
    };

/// 그리드 칸의 짧은 표시
String tagText(PhotoTag t, L10n l) => switch (t) {
  PhotoTag.best => l.tagBest,
  PhotoTag.burst => l.tagBurst,
  PhotoTag.blurry => l.tagBlurry,
  PhotoTag.junk => l.tagJunk,
  PhotoTag.original => l.tagOriginal,
  PhotoTag.duplicate => l.tagDuplicate,
};

/// 크게 볼 때 한 줄
String noteText(PhotoTag t, List<BestReason> reasons, L10n l) => switch (t) {
  PhotoTag.best =>
    reasons.isEmpty
        ? l.tagBest
        : l.noteBestWith(
            reasons
                .map(
                  (r) => switch (r) {
                    BestReason.sharp => l.reasonSharp,
                    BestReason.exposure => l.reasonExposure,
                  },
                )
                .join(' · '),
          ),
  PhotoTag.burst => l.noteBurst,
  PhotoTag.blurry => l.noteBlurry,
  PhotoTag.junk => l.noteJunk,
  PhotoTag.original => l.noteKeeper,
  PhotoTag.duplicate => l.tagDuplicate,
};

/// 정리할 사진(X)인가. 앱 추천은 [추천 보기]를 눌러야 X로 들어간다 (2026-10-22).
bool isMarked(String id, Map<String, Decision> decisions, SortSource src) =>
    stateOf(decisions, id) == DecisionState.toTrash;

SortSource watchSortSource(WidgetRef ref, SortKind kind, DayGroup? g) {
  final features = ref.watch(analysisProvider.select((s) => s.features));
  switch (kind) {
    case SortKind.duplicates:
      final sets = ref.watch(duplicatesProvider).value;
      if (sets == null) return const SortSource(photos: [], analyzing: true);
      final decisions = ref.watch(decisionsProvider).value ?? const {};
      bool gone(String id) {
        final s = stateOf(decisions, id);
        return s == DecisionState.toTrash || s == DecisionState.trashed;
      }

      // 묶음마다 하나는 남긴다: 원본을 정리하면 다음 사진이 남길 사진이 된다
      final keepers = {for (final s in sets) ?keeperOf(s, gone)};
      final all = [
        for (final s in sets) ...[s.keep, ...s.remove],
      ];
      return SortSource(
        photos: all,
        suggested: {
          for (final p in all)
            if (!keepers.contains(p.id)) p.id,
        },
        tags: {
          for (final p in all)
            p.id: keepers.contains(p.id)
                ? PhotoTag.original
                : PhotoTag.duplicate,
        },
        units: [
          for (final s in sets) [s.keep.id, ...s.remove.map((p) => p.id)],
        ],
      );
    case SortKind.screenshots:
      return SortSource(photos: g!.photos.reversed.toList());
    case SortKind.day:
    case SortKind.singles:
      final plan = ref.watch(groupPlanProvider(g!));
      final tags = <String, PhotoTag>{};
      final reasons = <String, List<BestReason>>{};
      for (final b in plan.bursts) {
        for (final p in b) {
          if (plan.best.contains(p.id)) {
            tags[p.id] = PhotoTag.best;
            reasons[p.id] = bestReasons(features[p.id], [
              for (final q in b) features[q.id],
            ]);
          }
        }
      }
      plan.trash.forEach((id, reason) {
        tags[id] = switch (reason) {
          TrashReason.burst => PhotoTag.burst,
          TrashReason.blurry => PhotoTag.blurry,
          TrashReason.junk => PhotoTag.junk,
        };
      });
      // 그날의 묶음 추천은 매달 무료 묶음 또는 Pro로 연다. 낱장 사진·캡처·중복은 무료.
      // 연속 컷 묶음(units)은 잠겨 있어도 넣는다: 전부 X로 보내면 "장면이 하나도 안 남아요"를 묻도록
      final units = [
        for (final b in plan.bursts)
          if (b.length > 1) [for (final p in b) p.id],
      ];
      if (kind == SortKind.day &&
          plan.trash.isNotEmpty &&
          !ref.watch(unlockedProvider(g.id))) {
        return SortSource(
          photos: g.photos,
          plan: plan,
          analyzing: plan.analyzed < g.count,
          units: units,
          locked: plan.trash.length,
        );
      }
      return SortSource(
        photos: kind == SortKind.singles
            ? g.photos.reversed.toList()
            : g.photos,
        suggested: plan.trash.keys.toSet(),
        tags: tags,
        bestReasons: reasons,
        plan: plan,
        analyzing: plan.analyzed < g.count,
        units: units,
      );
  }
}
