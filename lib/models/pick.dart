/// 추천 정확도 기록 한 줄 (SPEC 6-8). [휴지통으로]를 누른 순간, 그 화면의 사진마다
/// 앱이 추천했는지와 실제로 보냈는지를 남긴다. 폰 밖으로 나가지 않는다.
class PickRecord {
  const PickRecord({
    required this.at,
    required this.kind,
    required this.suggested,
    required this.sent,
    this.tag,
  });

  /// 보낸 시각 (같은 시각 = 한 번에 보낸 것)
  final DateTime at;

  /// 정리 화면 종류 (day, singles, duplicates)
  final String kind;

  /// 사진 위 표시 (burst, blurry, junk, duplicate, best …). 없으면 null
  final String? tag;

  /// 앱이 정리 추천했는가
  final bool suggested;

  /// 사용자가 실제로 휴지통으로 보냈는가
  final bool sent;
}
