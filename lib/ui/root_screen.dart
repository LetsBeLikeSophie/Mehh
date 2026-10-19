import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../providers.dart';
import '../theme.dart';
import 'hold_tab.dart';
import 'home_tab.dart';
import 'onboarding_screen.dart';

/// 권한이 없으면 온보딩, 있으면 하단 탭 2개 (묶음 / 보류함).
class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  late final AppLifecycleListener _lifecycle;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // 설정 앱에서 권한을 바꾸고 돌아오는 경우
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(permissionProvider.notifier).refresh(),
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

    return Scaffold(
      body: IndexedStack(index: _tab, children: const [HomeTab(), HoldTab()]),
      bottomNavigationBar: _BottomTabs(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _BottomTabs extends ConsumerWidget {
  const _BottomTabs({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final held = ref.watch(heldProvider).length;
    final labels = ['묶음', held > 0 ? '보류함 $held' : '보류함'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MehhColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 4),
                          decoration: i == index
                              ? const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: MehhColors.black,
                                      width: 2,
                                    ),
                                  ),
                                )
                              : null,
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: i == index
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: i == index
                                  ? MehhColors.black
                                  : MehhColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
