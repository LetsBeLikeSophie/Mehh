/// 앱 용어 (SPEC 5-0). 같은 행동은 모든 화면에서 같은 말로 부른다.
/// 화면에서 이 말들을 직접 쓰지 말고 여기서 가져온다.
abstract final class Terms {
  /// 남기기로 결정 (이후 추천에서 빠짐)
  static const keep = '킵';

  /// 30일 유예
  static const hold = '보류';

  /// 지울 후보에 넣기 (아직 안 지움)
  static const pile = '정리';
  static const pileRow = '정리 줄';

  /// 휴대폰 휴지통으로 실제로 보내기. OS 휴지통으로 가는 버튼은 항상 이 말
  static const toTrash = '휴지통으로';

  /// 아직 결정하지 않은 사진
  static const left = '남은';
}
