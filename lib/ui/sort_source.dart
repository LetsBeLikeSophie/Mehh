import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/duplicates.dart';
import '../logic/format.dart';
import '../logic/recommend.dart';
import '../models/day_group.dart';
import '../models/decision.dart';
import '../models/photo_meta.dart';
import '../providers.dart';

/// 정리 화면에 들어가는 것: 그날의 묶음, 한 장 사진, 캡처, 똑같은 사진
enum SortKind { day, singles, screenshots, duplicates }

/// 정리 화면(그리드)과 크게 보기가 함께 쓰는 사진 목록과 앱 추천
class SortSource {
  const SortSource({
    required this.photos,
    this.suggested = const {},
    this.tags = const {},
    this.notes = const {},
    this.summary,
    this.analyzing = false,
    this.units = const [],
  });

  /// 보여줄 순서 (휴지통으로 간 사진 포함, 화면에서 거른다)
  final List<PhotoMeta> photos;

  /// 앱이 정리 추천한 사진 (사용자가 바꾸기 전까지 X가 켜져 있다)
  final Set<String> suggested;

  /// 그리드 칸 위 짧은 표시 ("베스트", "비슷한 컷", "흔들림", "실수", "똑같은 사진")
  final Map<String, String> tags;

  /// 크게 볼 때 한 줄 ("베스트 · 초점 선명", "더 선명한 컷이 있어요")
  final Map<String, String> notes;

  final String? summary;
  final bool analyzing;

  /// 연속 컷·중복 묶음 (2장 이상). 통째로 휴지통으로 가면 한 번 묻는다.
  final List<List<String>> units;
}

String sortTitle(SortKind kind, DayGroup? g, String? place) => switch (kind) {
  SortKind.duplicates => '똑같은 사진',
  _ => groupTitle(g!, place: place),
};

/// 정리할 사진(X)인가: 직접 정리로 정했거나, 아직 안 정했는데 앱이 추천한 것
bool isMarked(String id, Map<String, Decision> decisions, SortSource src) {
  final s = stateOf(decisions, id);
  return s == DecisionState.toTrash ||
      (s == DecisionState.undecided && src.suggested.contains(id));
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
      return SortSource(
        photos: all,
        suggested: {
          for (final p in all)
            if (!keepers.contains(p.id)) p.id,
        },
        tags: {
          for (final p in all) p.id: keepers.contains(p.id) ? '원본' : '똑같은 사진',
        },
        notes: {
          for (final p in all)
            p.id: keepers.contains(p.id) ? '남길 사진' : '똑같은 사진',
        },
        summary: '줄마다 하나만 남기고 똑같은 사진에 X를 쳐 뒀어요',
        units: [
          for (final s in sets) [s.keep.id, ...s.remove.map((p) => p.id)],
        ],
      );
    case SortKind.screenshots:
      return SortSource(photos: g!.photos.reversed.toList());
    case SortKind.day:
    case SortKind.singles:
      final plan = ref.watch(groupPlanProvider(g!));
      final tags = <String, String>{};
      final notes = <String, String>{};
      for (final b in plan.bursts) {
        for (final p in b) {
          if (plan.best.contains(p.id)) {
            final r = bestReason(features[p.id], [
              for (final q in b) features[q.id],
            ]);
            tags[p.id] = '베스트';
            notes[p.id] = r.isEmpty ? '베스트' : '베스트 · $r';
          }
        }
      }
      plan.trash.forEach((id, reason) {
        tags[id] = switch (reason) {
          TrashReason.burst => '비슷한 컷',
          TrashReason.blurry => '흔들림',
          TrashReason.junk => '실수',
        };
        notes[id] = switch (reason) {
          TrashReason.burst => '비슷한 연속 컷',
          TrashReason.blurry => '더 선명한 컷이 있어요',
          TrashReason.junk => '실수로 찍힌 것 같아요',
        };
      });
      final summary = trashSummary(plan);
      return SortSource(
        photos: kind == SortKind.singles
            ? g.photos.reversed.toList()
            : g.photos,
        suggested: plan.trash.keys.toSet(),
        tags: tags,
        notes: notes,
        summary: summary.isEmpty ? null : summary,
        analyzing: plan.analyzed < g.count,
        units: [
          for (final b in plan.bursts)
            if (b.length > 1) [for (final p in b) p.id],
        ],
      );
  }
}
