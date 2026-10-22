import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../config/app_config.dart';
import '../providers.dart';
import 'home_tab.dart';
import 'onboarding_screen.dart';

/// 권한이 없으면 온보딩, 있으면 홈 (보류함 탭은 2026-10-21에 없앰).
class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // 설정 앱에서 권한을 바꾸고 돌아오는 경우 + 오래 지났으면 그 사이 찍은 사진도 불러온다
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(permissionProvider.notifier).refresh();
        ref.read(libraryProvider.notifier).refreshIfStale(reloadLibraryAfter);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 일부 허용 → 전체 허용처럼 접근 범위가 바뀌면 다시 불러온다
    ref.listen(permissionProvider, (prev, next) {
      if (prev != null && prev.hasAccess && next != prev) {
        ref.read(libraryProvider.notifier).reload();
      }
    });
    final permission = ref.watch(permissionProvider);
    if (permission == null) return const Scaffold();
    if (!permission.hasAccess) return const OnboardingScreen();
    return const Scaffold(body: HomeTab());
  }
}
