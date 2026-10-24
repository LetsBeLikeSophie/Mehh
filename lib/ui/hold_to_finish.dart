import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../theme.dart';

/// 길게 누르기 = 언제나 "정리 끝내기" (정리 화면 그리드·크게 보기 공용, 2026-10-24 Sophie).
/// - 누르는 동안 손가락 자리에 동그라미가 차오르고, 다 차면 [onDone] (지금 선택한 사진 기준으로 묻는다)
/// - 다 차기 전에 떼거나 밀면 아무 일도 없다
/// - 눈에 안 보이는 손동작이라, 선택한 사진이 있을 때 잠깐 멈추면 가운데에 "길게 누르면 정리를 끝낼 수 있어요".
///   통틀어 [finishHintsTotal]번까지, 길게 누르기를 한 번 써 보면 더 띄우지 않는다 (2026-10-24 Sophie)
/// 기기 안 `counters` 표의 키
const finishHintKey = 'finishHintShown';
const finishUsedKey = 'finishUsed';

class HoldToFinish extends ConsumerStatefulWidget {
  const HoldToFinish({
    super.key,
    required this.onDone,
    required this.armed,
    required this.child,
  });

  final VoidCallback onDone;

  /// 선택한 사진이 있다 (안내는 이때만)
  final bool armed;
  final Widget child;

  @override
  ConsumerState<HoldToFinish> createState() => _HoldToFinishState();
}

class _HoldToFinishState extends ConsumerState<HoldToFinish>
    with SingleTickerProviderStateMixin {
  late final _hold =
      AnimationController(vsync: this, duration: focusHoldToFinish)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _done();
        });
  Offset? _at;
  Timer? _idle;
  bool _hint = false;

  @override
  void initState() {
    super.initState();
    _restartIdle();
  }

  @override
  void didUpdateWidget(HoldToFinish old) {
    super.didUpdateWidget(old);
    if (widget.armed != old.armed) _restartIdle();
  }

  @override
  void dispose() {
    _idle?.cancel();
    _hold.dispose();
    super.dispose();
  }

  void _start(Offset at) {
    setState(() => _at = at);
    _hold.forward(from: 0);
  }

  void _stop() {
    _hold.reset();
    if (_at != null && mounted) setState(() => _at = null);
  }

  void _done() {
    _stop();
    _idle?.cancel();
    if (_hint) setState(() => _hint = false);
    // 한 번 써 봤으면 안내는 더 띄우지 않는다
    ref.read(storeProvider).bumpCounter(finishUsedKey);
    widget.onDone();
  }

  /// 선택한 사진이 있을 때 잠깐 멈추면 안내 (두 화면이 같이 센다)
  void _restartIdle() {
    _idle?.cancel();
    if (_hint) setState(() => _hint = false);
    if (!widget.armed) return;
    _idle = Timer(focusIdleHint, () async {
      final store = ref.read(storeProvider);
      if (await store.counter(finishUsedKey) > 0 ||
          await store.counter(finishHintKey) >= finishHintsTotal ||
          !mounted) {
        return;
      }
      await store.bumpCounter(finishHintKey);
      if (!mounted) return;
      setState(() => _hint = true);
      _idle = Timer(focusHintShown, () {
        if (mounted) setState(() => _hint = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _restartIdle(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPressDown: (d) => _start(d.localPosition),
        onLongPressCancel: _stop,
        onLongPressUp: _stop,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            Center(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _hint ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: MehhColors.black,
                      borderRadius: BorderRadius.circular(MehhRadius.chip),
                    ),
                    child: Text(
                      context.l.focusHint,
                      style: const TextStyle(
                        fontSize: MehhText.body,
                        fontWeight: FontWeight.w600,
                        color: MehhColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_at case final at?)
              Positioned(
                left: at.dx - 36,
                top: at.dy - 36,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _hold,
                    // 잠깐 누른 것(누르기·밀기)에는 보이지 않게 조금 뒤부터
                    builder: (_, _) => Opacity(
                      opacity: _hold.value > 0.15 ? 1 : 0,
                      child: Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: MehhColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircularProgressIndicator(
                          value: _hold.value,
                          strokeWidth: 4,
                          color: MehhColors.black,
                          backgroundColor: MehhColors.border,
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
