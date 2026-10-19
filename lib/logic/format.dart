import '../models/day_group.dart';

// 한국어 문구. 다국어는 7단계에서 옮긴다.

String formatDate(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final md = '${d.month}월 ${d.day}일';
  return d.year == n.year ? md : '${d.year}년 $md';
}

String formatTime(DateTime d) {
  final ampm = d.hour < 12 ? '오전' : '오후';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$ampm $h:${d.minute.toString().padLeft(2, '0')}';
}

/// "10월 3일 · 롯데월드", "10월 3일", "9월 · 캡처 모음"
String groupTitle(DayGroup g, {String? place, DateTime? now}) {
  final n = now ?? DateTime.now();
  if (g.kind == DayGroupKind.screenshots) return '캡처';
  if (g.kind == DayGroupKind.singles) return '한 장 사진';
  final date = formatDate(g.start, now: n);
  return place == null || place.isEmpty ? date : '$date · $place';
}

/// "오후 1:12 – 8:40", 날짜를 넘기면 "10월 3일 – 10월 4일"
String groupTimeRange(DayGroup g, {DateTime? now}) {
  final s = g.start, e = g.end;
  if (g.kind != DayGroupKind.day ||
      s.year != e.year ||
      s.month != e.month ||
      s.day != e.day) {
    final a = formatDate(s, now: now), b = formatDate(e, now: now);
    return a == b ? a : '$a – $b';
  }
  final a = formatTime(s), b = formatTime(e);
  if (a == b) return a;
  // 같은 오전/오후면 뒤쪽은 시각만
  final sameHalf = (s.hour < 12) == (e.hour < 12);
  return '$a – ${sameHalf ? b.split(' ').last : b}';
}
