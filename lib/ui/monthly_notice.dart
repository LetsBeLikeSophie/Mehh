import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notices.dart';
import '../data/pro.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import 'widgets.dart';

/// 매달 알림 글: 코인이 다시 생긴다는 말은 코인을 쓰는 사람에게만.
/// 테스트 동안 무료면 Pro 안내와 같은 말 (2026-10-26 Sophie)
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

/// 첫 [휴지통으로]가 성공한 뒤 한 번만 묻는다 (2026-10-29 Sophie B2-B)
Future<void> askMonthlyNotice(BuildContext context, WidgetRef ref) async {
  final store = ref.read(storeProvider);
  if (!ref.read(noticesProvider).supported ||
      await store.counter(_asked) > 0 ||
      !context.mounted) {
    return;
  }
  await store.bumpCounter(_asked);
  if (!context.mounted) return;
  final l = context.l;
  final yes = await askMehh(
    context,
    title: l.noticeAskTitle,
    body: l.noticeAskBody,
    no: l.noticeAskNo,
    yes: l.noticeAskYes,
  );
  if (yes && context.mounted) await turnOnMonthlyNotice(context, ref);
}

const _asked = 'noticeAsked';

Future<void> turnOnMonthlyNotice(BuildContext context, WidgetRef ref) async {
  final ok = await ref
      .read(noticesProvider)
      .turnOn(monthlyNoticeText(context, ref));
  ref.invalidate(monthlyNoticeProvider);
  if (context.mounted) {
    showNote(context, ok ? context.l.noticeOn : context.l.noticeBlocked);
  }
}

/// 켜져 있으면 알림 글을 지금 상태(Pro·테스트 무료)로 다시 맞춘다. 앱을 켜거나 돌아올 때
Future<void> refreshMonthlyNotice(BuildContext context, WidgetRef ref) =>
    ref.read(noticesProvider).refresh(monthlyNoticeText(context, ref));

Future<void> turnOffMonthlyNotice(WidgetRef ref) async {
  await ref.read(noticesProvider).turnOff();
  ref.invalidate(monthlyNoticeProvider);
}
