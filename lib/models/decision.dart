/// 사용자 결정 (SPEC 6-5).
/// [toTrash]: 정리 줄에 넣어 둔 사진 (휴지통으로 보내기 전, 언제든 되돌릴 수 있다)
/// [hold]: 더 이상 쓰지 않는다 (2026-10-21 보류 없앰). 예전에 저장된 값은 표시 없음으로 본다.
enum DecisionState { undecided, keep, hold, toTrash, trashed }

class Decision {
  const Decision({
    required this.photoId,
    required this.state,
    required this.at,
    this.holdAt,
  });

  final String photoId;
  final DecisionState state;
  final DateTime at;

  /// 보류한 시각 (hold일 때만)
  final DateTime? holdAt;
}
