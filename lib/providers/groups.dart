part of '../providers.dart';

// 열어 둔 묶음 다시 찾기, 바꾼 묶음 이름

/// 정리 화면을 연 뒤 사진첩이 바뀌었으면(새로 찍은 사진·다시 묶임) 지금의 같은 묶음.
/// 같은 종류에서 그날의 묶음은 같은 id 먼저, 아니면 사진이 가장 많이 겹치는 것. 못 찾으면 [old]
/// (열어 둔 정리 화면도 새 캡처를 보게, UX-70 2026-10-27)
DayGroup? freshGroup(List<DayGroup> groups, DayGroup? old) {
  if (old == null) return null;
  final ids = {for (final p in old.photos) p.id};
  DayGroup? best;
  var most = 0;
  for (final g in groups) {
    if (g.kind != old.kind) continue;
    if (g.kind == DayGroupKind.day && g.id == old.id) {
      best = g;
      break;
    }
    final n = g.photos.where((p) => ids.contains(p.id)).length;
    if (n > most) {
      most = n;
      best = g;
    }
  }
  // 찾으면 늘 사진첩의 것: 사진 구성이 같아도 ♥·앨범 이동 같은 표시가 바뀌었을 수 있다 (S-1 2026-10-28)
  if (best == null) return old;
  if (old.kind != DayGroupKind.day) return best;
  return _keepOpened(groups, best, old);
}

/// 그날의 묶음이 열려 있는 동안 다시 묶여(첫 장소 확인 등) 갈라져도, 연 묶음 사진 중
/// 사진첩에 아직 있는 것은 그대로 보인다(새 메타데이터로). 지운 사진은 빠지고 새 사진은 붙는다.
/// 다시 열면 갈린 묶음으로 보인다 (UX-75 2026-10-28)
DayGroup _keepOpened(List<DayGroup> groups, DayGroup now, DayGroup old) {
  final last = _lastKept;
  if (last != null && identical(last.$1, now) && identical(last.$2, old)) {
    return last.$3;
  }
  final have = {for (final p in now.photos) p.id};
  final wanted = {for (final p in old.photos) p.id}..removeAll(have);
  final DayGroup out;
  if (wanted.isEmpty) {
    out = now;
  } else {
    final moved = [
      for (final g in groups)
        for (final p in g.photos)
          if (wanted.contains(p.id)) p,
    ];
    out = moved.isEmpty
        ? now
        : DayGroup(
            id: now.id,
            kind: now.kind,
            photos: [...now.photos, ...moved]
              ..sort((a, b) => a.takenAt.compareTo(b.takenAt)),
            centerLat: now.centerLat,
            centerLng: now.centerLng,
          );
  }
  _lastKept = (now, old, out);
  return out;
}

/// 같은 입력이면 같은 묶음 객체를 돌려준다 (묶음별 추천 계산이 매번 새로 돌지 않게)
(DayGroup, DayGroup, DayGroup)? _lastKept;

/// [g]의 바꾼 이름. 없으면 null (기본 이름을 쓴다)
String? groupNameOf(
  Map<String, GroupName>? names,
  DayGroup? g, {
  Iterable<DayGroup> all = const [],
}) => names?[groupNameKey(names, g, all: all)]?.name;

/// 사용자가 바꾼 묶음 이름 (2026-10-24 Sophie). 기본 이름은 따로 계산하므로 언제든 되돌릴 수 있다
class GroupNamesNotifier extends AsyncNotifier<Map<String, GroupName>> {
  @override
  Future<Map<String, GroupName>> build() => ref.read(storeProvider).loadNames();

  /// [name]이 비었거나 null이면 기본 이름으로 되돌린다
  Future<void> rename(DayGroup group, String? name) async {
    final v = name?.trim();
    final keep = v == null || v.isEmpty ? null : v;
    final store = ref.read(storeProvider);
    final next = {...state.value ?? {}};
    // 옛 id로 남아 있던 이름은 지금 id로 옮긴다
    final old = groupNameKey(
      next,
      group,
      all: ref.read(libraryProvider).value?.groups ?? const [],
    );
    if (old != null && old != group.id) {
      await store.saveName(old, null);
      next.remove(old);
    }
    final ids = [for (final p in group.photos) p.id];
    await store.saveName(group.id, keep, photoIds: ids);
    if (keep == null) {
      next.remove(group.id);
    } else {
      next[group.id] = GroupName(keep, ids.toSet());
    }
    state = AsyncData(next);
  }
}

final groupNamesProvider =
    AsyncNotifierProvider<GroupNamesNotifier, Map<String, GroupName>>(
      GroupNamesNotifier.new,
    );
