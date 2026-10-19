/// 사진 한 장의 분석 결과 (기기 안에서 썸네일로 계산).
class PhotoFeatures {
  const PhotoFeatures({
    required this.id,
    required this.hashHi,
    required this.hashLo,
    required this.sharpness,
    required this.brightness,
    this.contrast = 50,
    this.modifiedAt = 0,
  });

  final String id;

  /// 64bit dHash를 32bit 두 개로 나눠 담는다 (웹에서도 비트 연산이 맞도록).
  final int hashHi;
  final int hashLo;

  /// 라플라시안 분산. 클수록 선명.
  final double sharpness;

  /// 평균 밝기 0~255.
  final double brightness;

  /// 밝기 표준편차. 낮으면 화면이 거의 한 가지 색 (주머니·렌즈 가림).
  final double contrast;

  /// 분석 당시 사진 수정 시각 (초). 바뀌면 다시 분석한다.
  final int modifiedAt;

  int hammingTo(PhotoFeatures o) =>
      popCount32(hashHi ^ o.hashHi) + popCount32(hashLo ^ o.hashLo);
}

int popCount32(int x) {
  x = x & 0xFFFFFFFF;
  var c = 0;
  while (x != 0) {
    x &= x - 1;
    c++;
  }
  return c;
}
