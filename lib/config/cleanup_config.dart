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
    this.bestMargin = 0.3,
    this.oldScreenshot = const Duration(days: 90),
    this.learnMinSamples = 20,
    this.learnMinAcceptRate = 0.5,
    this.learnWindow = const Duration(days: 30),
  });

  /// 취향 학습은 이 기간의 기록만 본다. 꺼진 이유는 새 기록이 안 쌓이니 이 기간이 지나면
  /// 다시 추천해 볼 기회가 생긴다 (2026-10-23 Sophie L1-B)
  final Duration learnWindow;

  /// 취향 학습 (6단계 작게 시작, 2026-10-22 Sophie L1-A): 한 이유(비슷한 컷·흔들림·실수)로
  /// 추천한 사진을 [learnMinSamples]장 넘게 봤는데 받아들인 비율이 [learnMinAcceptRate]보다
  /// 낮으면, 그 이유로는 더 추천하지 않는다.
  final int learnMinSamples;
  final double learnMinAcceptRate;

  /// 이보다 오래된 캡처는 정리 추천 (2026-10-22 Sophie C4-A). 연달아 찍은 비슷한 캡처는
  /// [burstMaxGap]·[burstMaxHamming] 기준으로 묶어 마지막 한 장만 남긴다.
  final Duration oldScreenshot;

  /// 연속 컷에서 1등과 2등의 점수([score]) 차이가 이 이상일 때만 "베스트"라고 부른다.
  /// 0.3 ≈ 약 35% 더 선명. 애매하면 가장 나중 컷을 이름 없이 남긴다 (2026-10-24 Sophie)
  final double bestMargin;

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
