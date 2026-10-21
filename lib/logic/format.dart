import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/day_group.dart';

// 날짜·시간은 언어별 형식으로 (ko: "10월 3일", "오후 1:12" / en: "Oct 3", "1:12 PM").

/// [withYear]가 false면 올해가 아니어도 연도를 뺀다 (홈 목록은 연도 구분선이 대신 보여 준다)
String formatDate(
  DateTime d,
  String locale, {
  DateTime? now,
  bool withYear = true,
}) {
  final n = now ?? DateTime.now();
  return !withYear || d.year == n.year
      ? DateFormat.MMMd(locale).format(d)
      : DateFormat.yMMMd(locale).format(d);
}

String formatTime(DateTime d, String locale) => DateFormat.jm(locale).format(d);

/// 0.823 → "82%" (언어별 형식)
String formatPercent(double v, String locale) =>
    NumberFormat.percentPattern(locale).format(v);

/// "10월 3일 · 롯데월드", "10월 3일", "캡처".
/// 홈 목록은 [withYear] false (연도 구분선 아래라 연도가 겹친다), 묶음 화면은 올해가 아니면 연도까지.
String groupTitle(
  DayGroup g,
  L10n l, {
  String? place,
  DateTime? now,
  bool withYear = true,
}) {
  if (g.kind == DayGroupKind.screenshots) return l.screenshots;
  if (g.kind == DayGroupKind.singles) return l.singles;
  final date = formatDate(g.start, l.localeName, now: now, withYear: withYear);
  return place == null || place.isEmpty ? date : '$date · $place';
}

/// "오후 1:12 – 오후 8:40", 날짜를 넘기면 "10월 3일 – 10월 4일"
String groupTimeRange(DayGroup g, L10n l, {DateTime? now}) {
  final s = g.start, e = g.end;
  final locale = l.localeName;
  if (g.kind != DayGroupKind.day ||
      s.year != e.year ||
      s.month != e.month ||
      s.day != e.day) {
    final a = formatDate(s, locale, now: now);
    final b = formatDate(e, locale, now: now);
    return a == b ? a : '$a – $b';
  }
  final a = formatTime(s, locale), b = formatTime(e, locale);
  return a == b ? a : '$a – $b';
}
