import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notices.dart';
import '../data/pro.dart';
import '../l10n/l10n.dart';
import '../logic/format.dart';
import '../providers.dart';
import 'widgets.dart';

/// 매달 알림 글: 코인이 다시 생긴다는 말은 코인을 쓰는 사람에게만.
/// 테스트 동안 무료면 Pro 안내와 같은 말 (2026-10-26 Sophie).
/// Pro 상태를 다 읽은 뒤에 불러야 한다([_noticeText]): 앱을 켠 직후엔 아직 비어 있다
NoticeText monthlyNoticeText(BuildContext context, WidgetRef ref) {
  final l = context.l;
  final channel = l.noticeSetting;
  if (ref.read(closedTestFreeProvider)) {
    return (title: l.noticeSetsTitle, body: l.proTestFree, channel: channel);
  }
  if (ref.read(proProvider).value?.pro ?? false) {
    return (title: l.noticeSetsTitle, body: l.noticeProBody, channel: channel);
  }
  return (
    title: l.noticeCoinsTitle(freeGroupsPerMonth),
    body: l.noticeCoinsBody,
    channel: channel,
  );
}

/// 이번 달 코인을 다 쓴 뒤 한 번만 묻는다: 1일에 다시 생기면 알려 줄지
/// (2026-10-29 Sophie B2-B, 10-30: 첫 [휴지통으로] 뒤가 아니라 코인을 다 쓴 뒤로).
/// Pro·테스트 동안 무료면 코인을 쓰지 않으니 묻지 않는다 (설정의 [매달 알림]으로 켠다)
Future<void> askMonthlyNotice(BuildContext context, WidgetRef ref) async {
  final store = ref.read(storeProvider);
  if (!ref.read(noticesProvider).supported ||
      ref.read(closedTestFreeProvider)) {
    return;
  }
  final now = DateTime.now();
  final s = await ref.read(proProvider.future);
  if (s.pro || s.freeLeft(now) > 0 || await store.counter(_asked) > 0) return;
  await store.bumpCounter(_asked);
  if (!context.mounted) return;
  final l = context.l;
  final yes = await askMehh(
    context,
    title: l.noticeAskTitle,
    body: l.noticeAskBody(
      formatDate(nextFreeReset(now), l.localeName),
      freeGroupsPerMonth,
    ),
    no: l.noticeAskNo,
    yes: l.noticeAskYes,
  );
  if (yes && context.mounted) await turnOnMonthlyNotice(context, ref);
}

const _asked = 'noticeAsked';

/// Pro 상태를 다 읽은 뒤의 알림 글. 화면이 닫혔으면 null
Future<NoticeText?> _noticeText(BuildContext context, WidgetRef ref) async {
  await ref.read(proProvider.future);
  return context.mounted ? monthlyNoticeText(context, ref) : null;
}

Future<void> turnOnMonthlyNotice(BuildContext context, WidgetRef ref) async {
  final text = await _noticeText(context, ref);
  if (text == null) return;
  final ok = await ref.read(noticesProvider).turnOn(text);
  ref.invalidate(monthlyNoticeProvider);
  if (context.mounted) {
    showNote(context, ok ? context.l.noticeOn : context.l.noticeBlocked);
  }
}

/// 켜져 있으면 알림 글을 지금 상태(Pro·테스트 무료)로 다시 맞춘다. 앱을 켜거나 돌아올 때,
/// Pro가 바뀔 때. Pro를 읽기 전에 맞추면 Pro 사용자에게 코인 글이 간다 (리뷰 2026-10-30 S-1)
Future<void> refreshMonthlyNotice(BuildContext context, WidgetRef ref) async {
  final text = await _noticeText(context, ref);
  if (text != null) await ref.read(noticesProvider).refresh(text);
}

Future<void> turnOffMonthlyNotice(WidgetRef ref) async {
  await ref.read(noticesProvider).turnOff();
  ref.invalidate(monthlyNoticeProvider);
}
