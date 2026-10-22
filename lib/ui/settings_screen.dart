import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

import '../l10n/l10n.dart';
import '../providers.dart';
import '../theme.dart';
import 'accuracy_screen.dart';
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
                  const SizedBox(height: 12),
                  _Section(
                    title: context.l.privacyTitle,
                    lines: [
                      context.l.privacyLocal,
                      context.l.privacyGeocode,
                      context.l.privacyTrash,
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _confirmClear(context, ref),
                      child: Text(context.l.clearAll),
                    ),
                  ),
                  if (supportEmail.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _contact(context),
                        child: Text(context.l.contact),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l.contactNote(supportEmail),
                      style: const TextStyle(
                        fontSize: MehhText.caption,
                        color: MehhColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MehhColors.surface,
        borderRadius: BorderRadius.circular(MehhRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: MehhText.body,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final l in lines) ...[
            const SizedBox(height: 8),
            Text(
              l,
              style: const TextStyle(
                fontSize: MehhText.caption,
                color: MehhColors.textMuted,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }
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
    final status = s == null
        ? ''
        : s.pro
        ? l.proUsing
        : l.freeSetsLeft(s.freeLeft(DateTime.now()));
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
              Text(
                status,
                style: const TextStyle(
                  fontSize: MehhText.caption,
                  color: MehhColors.textMuted,
                ),
              ),
              const Icon(Icons.chevron_right, color: MehhColors.icon),
            ],
          ),
        ),
      ),
    );
  }
}
