import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

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
              Image.asset('assets/mehh-goat.png', width: 88, height: 100),
              const SizedBox(height: 28),
              const Text(
                '사진 정리,\n제가 먼저 해둘게요',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '찍은 날짜와 장소로 사진을 묶고, 똑같은 사진을 찾으려면 '
                '사진 전체에 접근해야 해요.',
                style: TextStyle(
                  fontSize: 15,
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
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 20, color: MehhColors.text),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '사진은 폰 밖으로 나가지 않아요.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onPressed,
                  child: Text(
                    _denied ? '설정에서 허용하기' : '사진 접근 허용',
                    style: const TextStyle(
                      fontSize: 15,
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
