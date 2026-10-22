/// 중복·연속 컷·추천 기준값 (SPEC 6-2 ~ 6-4, 6-6). 튜닝은 여기서만 한다.
class CleanupConfig {
  const CleanupConfig({
    this.duplicateMaxHamming = 2,
    this.sameShotWindow = const Duration(minutes: 10),
    this.burstMaxGap = const Duration(seconds: 60),
    this.burstMaxHamming = 10,
    this.blurrySharpness = 12,
    this.darkBrightness = 12,
    this.pocketBrightness = 40,
    this.pocketContrast = 12,
    this.textScreenshot = 0.2,
    this.oldScreenshot = const Duration(days: 90),
  });

  /// 이보다 오래된 캡처는 정리 추천 (2026-10-22 Sophie C4-A). 연달아 찍은 비슷한 캡처는
  /// [burstMaxGap]·[burstMaxHamming] 기준으로 묶어 마지막 한 장만 남긴다.
  final Duration oldScreenshot;

  /// 글자 점수가 이 이상이면 "글자 있는 캡처"
  final double textScreenshot;

  /// dHash 해밍 거리가 이 이하이고 가로세로 비율이 같으면 중복.
  final int duplicateMaxHamming;

  /// 크기가 같고 이 시간 안에 찍힌 비슷한 사진은 연속 촬영일 수 있어서
  /// 파일 크기까지 같을 때만 중복으로 본다.
  final Duration sameShotWindow;

  /// 연속 컷: 이 간격 안에 찍혔고 해밍 거리가 기준 이하 (3단계 임시 기준).
  final Duration burstMaxGap;
  final int burstMaxHamming;

  /// 128px 썸네일 라플라시안 분산이 이보다 낮으면 심하게 흔들린 사진.
  final double blurrySharpness;

  /// 평균 밝기가 이보다 낮으면 까만 사진.
  final double darkBrightness;

  /// 주머니·렌즈 가림: 어둡고(밝기 < pocketBrightness) 거의 한 가지 색이고
  /// (대비 < pocketContrast) 흐린 사진.
  final double pocketBrightness;
  final double pocketContrast;
}
