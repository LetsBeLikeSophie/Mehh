/// 그날의 묶음 기준값 (SPEC 6-1). 튜닝은 여기서만 한다.
class GroupingConfig {
  const GroupingConfig({
    this.maxGap = const Duration(hours: 3),
    this.maxDistanceKm = 2.0,
    this.dayChangeGap = const Duration(hours: 1),
  });

  /// 직전 사진과 이 시간 이상 벌어지면 새 묶음.
  final Duration maxGap;

  /// 두 사진 모두 위치가 있고 이 거리 이상이면 새 묶음.
  final double maxDistanceKm;

  /// 날짜가 바뀌었고 이 시간 이상 벌어지면 새 묶음.
  final Duration dayChangeGap;
}
