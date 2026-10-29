import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../l10n/l10n.dart';
import '../providers.dart';
import '../theme.dart';

/// 첫 실행: 왜 사진 전체 접근이 필요한지 한 장으로 설명.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// 한 번 거절당하면 시스템 창이 다시 안 뜨므로 설정으로 보낸다.
  bool _denied = false;

  Future<void> _onPressed() async {
    final notifier = ref.read(permissionProvider.notifier);
    if (_denied) return notifier.openSettings();
    final s = await notifier.request();
    if (!s.hasAccess && mounted) setState(() => _denied = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // 받은 그림 그대로 (docs/design/mehh-logo-source.png)
              Image.asset(
                'assets/mehh-goat-mehh.png',
                width: 150,
                semanticLabel: 'Mehh',
              ),
              const SizedBox(height: 28),
              Text(
                context.l.onboardingTitle,
                style: TextStyle(
                  fontSize: MehhText.display,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l.onboardingBody,
                style: TextStyle(
                  fontSize: MehhText.body,
                  color: MehhColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MehhColors.surface,
                  borderRadius: BorderRadius.circular(MehhRadius.card),
                ),
                child: Column(
                  children: [
                    _Promise(Icons.lock_outline, context.l.promiseLocal),
                    // Cortex가 있으면 "폰 밖으로 안 나간다"의 예외를 바로 알린다 (2026-10-22 Sophie C1-A)
                    if (ref.watch(cortexInstalledProvider).value ?? false) ...[
                      const SizedBox(height: 12),
                      _Promise(Icons.north_east, context.l.privacyCortex),
                    ],
                    const SizedBox(height: 12),
                    _Promise(Icons.tune, context.l.promiseLearn),
                    const SizedBox(height: 12),
                    _Promise(Icons.undo, context.l.promiseRestore),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onPressed,
                  child: Text(
                    _denied ? context.l.allowInSettings : context.l.allowAccess,
                    style: const TextStyle(
                      fontSize: MehhText.body,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: MehhColors.text),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: MehhText.bodySmall,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
