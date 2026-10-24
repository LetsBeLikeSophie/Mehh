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
enum PhotoTag {
  best,
  burst,
  blurry,
  eyesClosed,
  junk,
  original,
  duplicate,
  oldShot,
  repeatShot,
}

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
    this.preMarked = const {},
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

  /// 틀릴 일이 거의 없어 [추천 보기] 없이 처음부터 X로 보이는 사진 (무료 종류만, 2026-10-22 Sophie R1-C):
  /// 낱장 사진의 "실수"(까맣거나 주머니 속), 똑같은 사진 중 그림 해시·크기까지 같은 사본.
  /// 결정으로 저장하지 않고 보이기만 한다 (X를 끄면 킵으로 저장).
  final Set<String> preMarked;
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
  PhotoTag.eyesClosed => l.tagEyesClosed,
  PhotoTag.junk => l.tagJunk,
  PhotoTag.original => l.tagOriginal,
  PhotoTag.duplicate => l.tagDuplicate,
  PhotoTag.oldShot => l.tagOldShot,
  PhotoTag.repeatShot => l.tagRepeatShot,
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
  PhotoTag.eyesClosed => l.noteEyesClosed,
  PhotoTag.junk => l.noteJunk,
  PhotoTag.original => l.noteKeeper,
  PhotoTag.duplicate => l.tagDuplicate,
  PhotoTag.oldShot => l.noteOldShot,
  PhotoTag.repeatShot => l.noteRepeatShot,
};

/// 정리할 사진(X)인가. 앱 추천은 [추천 보기]를 눌러야 X로 들어간다 (2026-10-22).
/// 예외: [SortSource.preMarked]는 아직 안 정했으면 처음부터 X.
bool isMarked(String id, Map<String, Decision> decisions, SortSource src) {
  final s = stateOf(decisions, id);
  return s == DecisionState.toTrash ||
      (s == DecisionState.undecided && src.preMarked.contains(id));
}

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
      // 남길 사진과 그림 해시·크기가 완전히 같은 사본은 처음부터 X
      bool identical(PhotoMeta a, PhotoMeta b) {
        final fa = features[a.id], fb = features[b.id];
        return fa != null &&
            fb != null &&
            fa.hashHi == fb.hashHi &&
            fa.hashLo == fb.hashLo &&
            a.width == b.width &&
            a.height == b.height;
      }

      final byId = {for (final p in all) p.id: p};
      return SortSource(
        photos: all,
        // ♥(즐겨찾기) 사본은 추천하지 않는다 (직접 X는 그대로)
        suggested: {
          for (final p in all)
            if (!keepers.contains(p.id) && !p.isFavorite) p.id,
        },
        preMarked: {
          for (final s in sets)
            if (keeperOf(s, gone) case final k?)
              for (final p in [s.keep, ...s.remove])
                if (p.id != k && !p.isFavorite && identical(p, byId[k]!)) p.id,
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
      // 캡처 추천은 무료 (2026-10-22 Sophie C4-A): 오래된 캡처, 연달아 찍은 캡처의 지난 장
      final decisions = ref.watch(decisionsProvider).value ?? const {};
      final picks = planScreenshots(
        g!.photos,
        features,
        decisions,
        now: DateTime.now(),
      );
      return SortSource(
        photos: g.photos.reversed.toList(),
        suggested: picks.keys.toSet(),
        tags: {
          for (final e in picks.entries)
            e.key: e.value == ShotReason.old
                ? PhotoTag.oldShot
                : PhotoTag.repeatShot,
        },
        // 같은 화면을 연달아 찍은 묶음: 통째로 보내면 "장면이 하나도 안 남아요"를 묻는다
        units: screenshotRuns(
          g.photos,
          features,
          decisions,
          now: DateTime.now(),
        ),
      );
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
          TrashReason.eyesClosed => PhotoTag.eyesClosed,
        };
      });
      // 그날의 묶음 추천은 매달 무료 묶음 또는 Pro로 연다. 낱장 사진·캡처·중복은 무료.
      // 연속 컷 묶음(units)은 잠겨 있어도 넣는다: 전부 X로 보내면 "장면이 하나도 안 남아요"를 묻도록
      final units = [
        for (final b in plan.bursts)
          if (b.length > 1) [for (final p in b) p.id],
      ];
      // 틀릴 일이 거의 없는 "실수"(까맣거나 주머니 속) 사진은 무료로 처음부터 X (낱장·그날의 묶음, Sophie P2-A).
      // 잠금(무료 묶음·Pro)은 비슷한 컷·흔들림·베스트 고르기에만 건다
      final junk = {
        for (final e in plan.trash.entries)
          if (e.value == TrashReason.junk) e.key,
      };
      final paid = plan.trash.length - junk.length;
      if (kind == SortKind.day && paid > 0 && !ref.watch(unlockedProvider(g))) {
        return SortSource(
          photos: g.photos,
          plan: plan,
          analyzing: plan.analyzed < g.count,
          units: units,
          locked: paid,
          suggested: junk,
          preMarked: junk,
          tags: {for (final id in junk) id: PhotoTag.junk},
        );
      }
      return SortSource(
        photos: kind == SortKind.singles
            ? g.photos.reversed.toList()
            : g.photos,
        suggested: plan.trash.keys.toSet(),
        preMarked: junk,
        tags: tags,
        bestReasons: reasons,
        plan: plan,
        analyzing: plan.analyzed < g.count,
        units: units,
      );
  }
}
