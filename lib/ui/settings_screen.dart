import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

import '../l10n/l10n.dart';
import '../providers.dart';
import '../theme.dart';
import 'accuracy_screen.dart';
import 'monthly_notice.dart';
import 'pro_sheet.dart';
import 'widgets.dart';

/// 설정: 개인정보 안내 + 이 폰에 남긴 기록 지우기
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l = context.l;
    final ok = await askMehh(
      context,
      title: l.clearTitle,
      body: l.clearBody,
      no: l.cancel,
      yes: l.clearConfirm,
    );
    if (!ok) return;
    await clearAllRecords(ref);
    if (context.mounted) showNote(context, context.l.cleared);
  }

  /// 메일 앱으로 문의. 메일 앱이 없으면 주소를 복사해 준다.
  Future<void> _contact(BuildContext context) async {
    final l = context.l;
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=${Uri.encodeComponent(l.contactSubject(appVersion))}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {}
    if (opened || !context.mounted) return;
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (context.mounted) showNote(context, l.contactCopied);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 20, 24),
          children: [
            const MehhBackButton(),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l.settings,
                    style: TextStyle(
                      fontSize: MehhText.title,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 구매 복원은 여기서도 찾을 수 있게 (UX 리뷰 2026-10-22). 새 화면 없이 Pro 안내를 연다
                  const _ProRow(),
                  // 알림은 코인이 다시 생긴다는 이야기라 Pro 줄 바로 아래 (2026-10-30 Sophie N2-B)
                  if (ref.watch(noticesProvider).supported) ...[
                    const SizedBox(height: 8),
                    const _MonthlyNoticeRow(),
                  ],
                  const SizedBox(height: 28),
                  // 긴 문장 대신 아이콘 + 짧은 줄 (2026-10-24 Sophie: 개발 화면처럼 보이지 않게)
                  _Heading(context.l.privacyTitle),
                  _Line(Icons.smartphone_outlined, context.l.privacyShortLocal),
                  _Line(Icons.place_outlined, context.l.privacyShortPlace),
                  _Line(Icons.face_outlined, context.l.privacyShortFaces),
                  _Line(Icons.delete_outline, context.l.privacyShortTrash),
                  if (ref.watch(cortexInstalledProvider).value ?? false)
                    _Line(Icons.north_east, context.l.privacyShortCortex),
                  const SizedBox(height: 28),
                  _Heading(context.l.helpTitle),
                  if (supportEmail.isNotEmpty)
                    _Tap(
                      icon: Icons.mail_outline,
                      label: context.l.contact,
                      sub: supportEmail,
                      onTap: () => _contact(context),
                    ),
                  _Tap(
                    icon: Icons.restart_alt,
                    label: context.l.clearAll,
                    sub: context.l.clearAllSub,
                    onTap: () => _confirmClear(context, ref),
                  ),
                  const SizedBox(height: 28),
                  MehhLink(context.l.privacyPolicy, privacyPolicyUrl),
                  MehhLink(context.l.termsRefunds, termsUrl),
                  // 버전 글자를 7번 누르면 추천 정확도 (숨은 화면, SPEC 6-8)
                  const _VersionTap(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: MehhText.bodySmall,
        fontWeight: FontWeight.w600,
        color: MehhColors.text,
      ),
    ),
  );
}

/// 아이콘 + 짧은 한 줄
class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: MehhColors.icon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: MehhText.caption,
              color: MehhColors.textMuted,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 누르는 줄 (아이콘 · 이름 · 작은 설명 · >)
class _Tap extends StatelessWidget {
  const _Tap({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(MehhRadius.button),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: MehhColors.text),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: MehhText.body,
                    color: MehhColors.text,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: MehhText.label,
                    color: MehhColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: MehhColors.icon),
        ],
      ),
    ),
  );
}

class _VersionTap extends StatefulWidget {
  const _VersionTap();

  @override
  State<_VersionTap> createState() => _VersionTapState();
}

class _VersionTapState extends State<_VersionTap> {
  var _taps = 0;

  void _tap() {
    if (++_taps < 7) return;
    _taps = 0;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AccuracyScreen()));
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _tap,
    child: const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Mehh $appVersion',
        style: TextStyle(fontSize: MehhText.label, color: MehhColors.textMuted),
      ),
    ),
  );
}

/// 설정 맨 위 "Mehh Pro" 줄: 지금 상태 한 줄, 누르면 Pro 안내(구매·구매 복원)
class _ProRow extends ConsumerWidget {
  const _ProRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final s = ref.watch(proProvider).value;
    final testFree = ref.watch(closedTestFreeProvider);
    return Material(
      color: MehhColors.surface,
      borderRadius: BorderRadius.circular(MehhRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(MehhRadius.card),
        onTap: () => showProSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                l.proTitle,
                style: const TextStyle(
                  fontSize: MehhText.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // 코인은 글자 대신 그림 + 남은 개수 (2026-10-24 Sophie)
              if (s != null)
                s.pro || testFree
                    ? Text(
                        s.pro ? l.proUsing : l.testFreeChip,
                        style: const TextStyle(
                          fontSize: MehhText.caption,
                          color: MehhColors.textMuted,
                        ),
                      )
                    : CoinCount(s.freeLeft(DateTime.now()), size: 20),
              const Icon(Icons.chevron_right, color: MehhColors.icon),
            ],
          ),
        ),
      ),
    );
  }
}

/// 매달 알림 켜고 끄기 (2026-10-29 Sophie B2-B). 폰 설정에서 끄면 돌아올 때 꺼짐으로 보인다
class _MonthlyNoticeRow extends ConsumerWidget {
  const _MonthlyNoticeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final on = ref.watch(monthlyNoticeProvider).value ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_none,
            size: 20,
            color: MehhColors.text,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.noticeSetting,
                  style: const TextStyle(
                    fontSize: MehhText.body,
                    color: MehhColors.text,
                  ),
                ),
                Text(
                  l.noticeSettingSub,
                  style: const TextStyle(
                    fontSize: MehhText.label,
                    color: MehhColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            activeTrackColor: MehhColors.black,
            onChanged: (v) => v
                ? turnOnMonthlyNotice(context, ref)
                : turnOffMonthlyNotice(ref),
          ),
        ],
      ),
    );
  }
}
