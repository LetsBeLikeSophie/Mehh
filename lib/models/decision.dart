/// 사용자 결정 (SPEC 6-5).
/// [toTrash]: 정리 줄에 넣어 둔 사진 (휴지통으로 보내기 전, 언제든 되돌릴 수 있다)
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

/// 앱 안에서 사진을 열어본 기록 (보류함 유예기간용).
class ViewRecord {
  const ViewRecord({required this.count, required this.lastAt});

  final int count;
  final DateTime lastAt;
}
