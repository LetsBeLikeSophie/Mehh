import '../config/cleanup_config.dart';
import '../models/decision.dart';

/// SPEC 6-6. 보류한 뒤(또는 마지막으로 열어본 뒤) 유예기간이 지나면 결정할 때.
DateTime holdDueAt(
  Decision d,
  ViewRecord? view, {
  CleanupConfig config = const CleanupConfig(),
}) {
  var from = d.holdAt ?? d.at;
  final lastView = view?.lastAt;
  if (lastView != null && lastView.isAfter(from)) from = lastView;
  return from.add(Duration(days: config.holdDays));
}

/// 남은 날 (D-6 → 6). 0 이하면 결정할 때.
int holdDaysLeft(DateTime dueAt, DateTime now) {
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(dueAt.year, dueAt.month, dueAt.day);
  return b.difference(a).inDays;
}
