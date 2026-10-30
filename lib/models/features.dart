/// 사진 한 장의 분석 결과 (기기 안에서 썸네일로 계산).
class PhotoFeatures {
  const PhotoFeatures({
    required this.id,
    required this.hashHi,
    required this.hashLo,
    required this.sharpness,
    required this.brightness,
    this.contrast = 50,
    this.textScore = 0,
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

  /// 글자 많은 화면일수록 1에 가깝다 (캡처를 글자/화면으로 나눌 때).
  final double textScore;

  /// 분석 당시 사진 수정 시각 (초). 바뀌면 다시 분석한다.
  final int modifiedAt;

  int hammingTo(PhotoFeatures o) =>
      popCount32(hashHi ^ o.hashHi) + popCount32(hashLo ^ o.hashLo);
}

int popCount32(int x) =>
    _pop8[x & 0xFF] +
    _pop8[(x >> 8) & 0xFF] +
    _pop8[(x >> 16) & 0xFF] +
    _pop8[(x >> 24) & 0xFF];

/// 0~255의 켜진 비트 수
final _pop8 = List<int>.generate(256, (i) {
  var c = 0;
  for (var x = i; x != 0; x &= x - 1) {
    c++;
  }
  return c;
}, growable: false);
