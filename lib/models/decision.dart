/// 사용자 결정 (SPEC 6-5).
enum DecisionState { undecided, keep, hold, trashed }

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
