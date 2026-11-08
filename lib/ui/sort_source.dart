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
enum SortKind {
  day,
  singles,
  screenshots,
  duplicates,
  videos,
  saved;

  /// 사진 대신 동영상을 보여 주는 종류 (세는 단위 "개", Cortex 없음)
  bool get isVideo => this == videos;

  /// 묶음마다 새 줄에서 시작해 어떤 것끼리 짝인지 보이는 종류
  bool get bySets => this == duplicates;
}

/// 그리드를 나누는 칸 하나 (동영상 날짜순: 달마다). 위에 작은 달 이름을 둘 수 있다
class SortSection {
  const SortSection(this.ids, {this.month});
  final List<String> ids;

  /// 칸 위 작은 달 이름 ("2026년 10월")
  final DateTime? month;
}

/// 동영상 보기 필터 (2026-11-08 Sophie): 어떤 것만 · 어떤 순서로
enum VideoShow { all, filmed, received }

enum VideoOrder { size, date }

typedef VideoView = ({VideoShow show, VideoOrder order});

/// 동영상 정리 화면의 필터. 앱이 켜져 있는 동안 마지막으로 고른 것을 기억한다 (처음엔 전체·용량순)
class VideoViewNotifier extends Notifier<VideoView> {
  @override
  VideoView build() => (show: VideoShow.all, order: VideoOrder.size);

  void show(VideoShow s) => state = (show: s, order: state.order);
  void order(VideoOrder o) => state = (show: state.show, order: o);
}

final videoViewProvider = NotifierProvider<VideoViewNotifier, VideoView>(
  VideoViewNotifier.new,
);

/// 필터에 들어오는 동영상, 보일 순서대로 (용량순: 큰 것부터, 날짜순: 최신부터)
List<PhotoMeta> videosShown(List<PhotoMeta> all, VideoView v) =>
    [
      for (final p in all)
        if (switch (v.show) {
          VideoShow.all => true,
          VideoShow.filmed => !p.fromOtherApp,
          VideoShow.received => p.fromOtherApp,
        })
          p,
    ]..sort(
      (a, b) => v.order == VideoOrder.size
          ? b.sizeBytes.compareTo(a.sizeBytes)
          : b.takenAt.compareTo(a.takenAt),
    );

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
  receivedVideo,
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
    this.alwaysTags = false,
    this.sections = const [],
    this.hidden = const [],
  });

  /// 필터로 지금 안 보이는 것 (동영상). 고른 표시는 따라가서, 보내기 버튼은 이것까지 센다 (2026-11-08 Sophie)
  final List<PhotoMeta> hidden;

  /// 그리드를 이 칸들로 나눠 보인다. 비면 [SortKind.bySets]면 [units]마다, 아니면 한 칸
  final List<SortSection> sections;

  /// 표시를 X·[추천 보기]와 상관없이 늘 보인다 (편집본·원본처럼 추천이 아닌 사실 표시)
  final bool alwaysTags;

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
  PhotoTag.receivedVideo => l.tagReceivedVideo,
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
  PhotoTag.receivedVideo => l.tagReceivedVideo,
};

/// 사진에 붙이는 이유 표시: X 사진에는 "왜 X인지", 남길 사진·베스트는 [추천 보기]를 받은 뒤에만
/// (2026-10-22). 그리드와 크게 보기가 같이 쓴다 (UX-86)
PhotoTag? shownTag(
  SortSource src,
  String id, {
  required bool marked,
  required bool picksShown,
}) {
  final t = src.tags[id];
  if (src.alwaysTags) return t;
  final keepTag = t == PhotoTag.best || t == PhotoTag.original;
  if (keepTag) return picksShown || src.preMarked.isNotEmpty ? t : null;
  return marked ? t : null;
}

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
      // 남길 사진과 그림 해시·크기가 완전히 같은 사본은 처음부터 X.
      // 카메라 폴더 밖 사본은 일부러 복사한 것일 수 있어 [추천 보기]로만 (2026-11-02 Sophie)
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
        suggested: {
          for (final p in all)
            if (!keepers.contains(p.id) && suggestableCopy(p)) p.id,
        },
        preMarked: {
          for (final s in sets)
            if (keeperOf(s, gone) case final k?)
              for (final p in [s.keep, ...s.remove])
                if (p.id != k &&
                    suggestableCopy(p) &&
                    !p.fromOtherApp &&
                    identical(p, byId[k]!))
                  p.id,
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
    case SortKind.videos:
      // 동영상 하나에 다 모으고 필터로 본다 (2026-11-08 Sophie: 짝 묶기는 하지 않는다).
      // 앱이 골라 주지 않는다 (2026-10-24 Sophie)
      final view = ref.watch(videoViewProvider);
      final shown = videosShown(g!.photos, view);
      final ids = {for (final p in shown) p.id};
      DateTime month(PhotoMeta p) => DateTime(p.takenAt.year, p.takenAt.month);
      return SortSource(
        photos: shown,
        hidden: [
          for (final p in g.photos)
            if (!ids.contains(p.id)) p,
        ],
        // 전체 보기에서만 받은 영상에 "받음" (받은 것만 볼 때는 다 받은 것이라 뺀다)
        tags: {
          if (view.show == VideoShow.all)
            for (final p in shown)
              if (p.fromOtherApp) p.id: PhotoTag.receivedVideo,
        },
        alwaysTags: true,
        // 날짜순은 달마다 작은 이름
        sections: view.order == VideoOrder.date
            ? [
                for (final m in {for (final p in shown) month(p)})
                  SortSection([
                    for (final p in shown)
                      if (month(p) == m) p.id,
                  ], month: m),
              ]
            : const [],
      );
    case SortKind.saved:
      // 저장한 사진: 최신이 위. 앱이 골라 주지 않는다 (2026-11-01 Sophie)
      return SortSource(photos: g!.photos.reversed.toList());
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
      final paid = paidPickCount(plan);
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
