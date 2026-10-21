import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../providers.dart';
import '../theme.dart';
import 'widgets.dart';

/// 설정: 개인정보 안내 + 이 폰에 남긴 기록 지우기
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MehhColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MehhRadius.card),
        ),
        title: Text(
          context.l.clearTitle,
          style: TextStyle(
            fontSize: MehhText.heading,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          context.l.clearBody,
          style: TextStyle(fontSize: MehhText.bodySmall, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            style: TextButton.styleFrom(foregroundColor: MehhColors.textMuted),
            child: Text(context.l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: TextButton.styleFrom(foregroundColor: MehhColors.black),
            child: Text(
              context.l.clearConfirm,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await clearAllRecords(ref);
    if (context.mounted) showNote(context, context.l.cleared);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 4, 20, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: context.l.home,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.chevron_left, color: MehhColors.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
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
                  const SizedBox(height: 24),
                  const Text(
                    'Mehh 1.3.0',
                    style: TextStyle(
                      fontSize: MehhText.label,
                      color: MehhColors.textMuted,
                    ),
                  ),
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
