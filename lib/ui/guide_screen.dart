import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'widgets.dart';

/// 처음 한 번 뜨는 사용법 네 장. 설정의 [사용법]으로 다시 본다 (2026-10-31 Sophie:
/// 써 본 사람이 묶음에 들어가 사진을 눌러 위아래로 미는 것 자체를 생각하지 못했다).
/// 그림은 파일이 아니라 위젯이라 앱 화면이 바뀌어도 여기만 고치면 된다.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen>
    with SingleTickerProviderStateMixin {
  static const _pages = 4;

  final _page = PageController();
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 폰에서 움직임 줄이기를 켰으면 멈춘 그림으로
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion
        ..stop()
        ..value = 0.25;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _pages - 1) {
      Navigator.of(context).pop();
      return;
    }
    _page.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final last = _index == _pages - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Visibility(
                  visible: !last,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l.guideSkip,
                      style: const TextStyle(
                        fontSize: MehhText.bodySmall,
                        color: MehhColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _page,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    _Page(
                      scene: _HomeScene(_motion),
                      title: l.guideGroupsTitle,
                      body: l.guideGroupsBody,
                    ),
                    _Page(
                      scene: _GridScene(_motion),
                      title: l.guideOpenTitle,
                      body: l.guideOpenBody,
                    ),
                    _Page(
                      scene: _SwipeScene(_motion),
                      title: l.guideSwipeTitle,
                      body: l.guideSwipeBody,
                    ),
                    _Page(
                      scene: _SendScene(_motion),
                      title: l.guideSendTitle,
                      body: l.guideSendBody,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: l.guidePosition(_index + 1, _pages),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pages; i++)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _index
                                ? MehhColors.black
                                : MehhColors.border,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    last ? l.guideStart : l.guideNext,
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

class _Page extends StatelessWidget {
  const _Page({required this.scene, required this.title, required this.body});

  final Widget scene;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ExcludeSemantics(child: _Phone(child: scene)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: MehhText.title,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: MehhText.body,
            color: MehhColors.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// 그림 속 작은 폰 화면
class _Phone extends StatelessWidget {
  const _Phone({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _sceneWidth,
      height: _sceneHeight,
      padding: const EdgeInsets.all(_scenePad),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: MehhColors.surface,
        borderRadius: BorderRadius.circular(MehhRadius.photo),
        border: Border.all(color: MehhColors.border),
      ),
      child: child,
    );
  }
}

const _sceneWidth = 220.0;
const _sceneHeight = 300.0;
const _scenePad = 12.0;
const _innerWidth = _sceneWidth - _scenePad * 2 - 2;
const _innerHeight = _sceneHeight - _scenePad * 2 - 2;

/// 누르는 손가락 자리. [t]가 0~1 사이에 한 번 눌렀다 뗀다
class _Finger extends StatelessWidget {
  const _Finger(this.t);

  final double t;

  @override
  Widget build(BuildContext context) {
    final press = t < 0.5 ? t * 2 : (1 - t) * 2;
    return Container(
      width: 34 - press * 8,
      height: 34 - press * 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MehhColors.black.withValues(alpha: 0.18 + press * 0.22),
        border: Border.all(color: MehhColors.white, width: 2),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({this.size, this.marked = false, this.selected = false});

  final double? size;
  final bool marked;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: marked ? MehhColors.border : MehhColors.icon,
        borderRadius: BorderRadius.circular(MehhRadius.thumb),
        border: selected ? Border.all(color: MehhColors.black, width: 2) : null,
      ),
      alignment: AlignmentDirectional.topEnd,
      padding: const EdgeInsets.all(3),
      child: marked ? const XMark() : null,
    );
  }
}

/// 1장: 홈의 묶음 줄 하나를 누른다
class _HomeScene extends AnimatedWidget {
  const _HomeScene(Animation<double> motion) : super(listenable: motion);

  double get _t => (listenable as Animation<double>).value;

  @override
  Widget build(BuildContext context) {
    Widget row(bool on) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: on ? MehhColors.tile : MehhColors.white,
        borderRadius: BorderRadius.circular(MehhRadius.tile),
      ),
      child: const Row(
        children: [
          _Tile(size: 40),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bar(width: 90, dark: true),
                SizedBox(height: 6),
                _Bar(width: 60),
              ],
            ),
          ),
        ],
      ),
    );
    return Stack(
      children: [
        Column(children: [row(_t < 0.5), row(false), row(false), row(false)]),
        PositionedDirectional(start: 96, top: 14, child: _Finger((_t * 2) % 1)),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, this.dark = false});

  final double width;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 8,
      decoration: BoxDecoration(
        color: dark ? MehhColors.textMuted : MehhColors.border,
        borderRadius: BorderRadius.circular(MehhRadius.strip),
      ),
    );
  }
}

/// 2장: 묶음 안 그리드에서 사진 하나를 누른다
class _GridScene extends AnimatedWidget {
  const _GridScene(Animation<double> motion) : super(listenable: motion);

  double get _t => (listenable as Animation<double>).value;

  @override
  Widget build(BuildContext context) {
    // 앞 절반은 누르기, 뒤 절반은 누른 사진이 크게 열린다
    final grow = Curves.easeOutCubic.transform(
      ((_t - 0.45) / 0.3).clamp(0.0, 1.0),
    );
    const gap = 6.0;
    final side = (_innerWidth - gap * 2) / 3;
    return Stack(
      children: [
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (var i = 0; i < 12; i++) _Tile(size: side)],
        ),
        Positioned(
          left: side + gap - (side + gap) * grow,
          top: side + gap - (side + gap) * grow,
          width: side + (_innerWidth - side) * grow,
          height: side + (_innerHeight - side) * grow,
          child: _Tile(selected: true),
        ),
        if (_t < 0.45)
          Positioned(
            left: side + gap + side / 2 - 17,
            top: side + gap + side / 2 - 17,
            child: _Finger(_t / 0.45),
          ),
      ],
    );
  }
}

/// 3장: 크게 보기. 위로 밀면 정리, 아래로 밀면 킵 (실제 화면의 위·아래 줄과 같은 말)
class _SwipeScene extends AnimatedWidget {
  const _SwipeScene(Animation<double> motion) : super(listenable: motion);

  double get _t => (listenable as Animation<double>).value;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    // 위로 갔다 돌아오고, 아래로 갔다 돌아온다
    double wave(double from, double to) {
      if (_t < from || _t > to) return 0;
      final p = (_t - from) / (to - from);
      return Curves.easeInOut.transform(p < 0.5 ? p * 2 : (1 - p) * 2);
    }

    final up = wave(0.0, 0.5);
    final down = wave(0.5, 1.0);
    final dy = (down - up) * 54;
    final moving = up > 0.3 || down > 0.3;
    // 사진이 위·아래 줄 뒤로 지나가게: 줄을 사진보다 나중에 그린다
    return Stack(
      children: [
        Positioned.fill(
          top: _swipeBarHeight + 8,
          bottom: _swipeBarHeight + 8,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox.expand(child: _Tile()),
                if (moving) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: MehhColors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      up > down ? Icons.arrow_upward : Icons.arrow_downward,
                      color: MehhColors.white,
                      size: 26,
                    ),
                  ),
                  // 미는 손가락 (화살표 옆)
                  const PositionedDirectional(
                    end: 24,
                    bottom: 24,
                    child: _Finger(0.5),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: _SwipeBar(Icons.arrow_upward, l.pile, on: up > 0.3),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _SwipeBar(Icons.arrow_downward, l.keep, on: down > 0.3),
        ),
      ],
    );
  }
}

const _swipeBarHeight = 32.0;

class _SwipeBar extends StatelessWidget {
  const _SwipeBar(this.icon, this.label, {required this.on});

  final IconData icon;
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final color = on ? MehhColors.white : MehhColors.text;
    return Container(
      height: _swipeBarHeight,
      decoration: BoxDecoration(
        color: on ? MehhColors.black : MehhColors.white,
        borderRadius: BorderRadius.circular(MehhRadius.button),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: MehhText.caption, color: color),
          ),
        ],
      ),
    );
  }
}

/// 4장: X로 고른 사진을 [N장 휴지통으로]로 보낸다
class _SendScene extends AnimatedWidget {
  const _SendScene(Animation<double> motion) : super(listenable: motion);

  double get _t => (listenable as Animation<double>).value;

  @override
  Widget build(BuildContext context) {
    const gap = 6.0;
    final side = (_innerWidth - gap * 2) / 3;
    const marked = {1, 4, 6};
    final sent = _t > 0.55;
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < 9; i++)
                    if (!(sent && marked.contains(i)))
                      _Tile(size: side, marked: marked.contains(i)),
                ],
              ),
            ),
            Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sent ? MehhColors.border : MehhColors.black,
                borderRadius: BorderRadius.circular(MehhRadius.button),
              ),
              child: Text(
                context.l.trashCount(marked.length),
                style: TextStyle(
                  fontSize: MehhText.caption,
                  color: sent ? MehhColors.textMuted : MehhColors.white,
                ),
              ),
            ),
          ],
        ),
        if (_t < 0.55)
          Positioned(
            left: _innerWidth / 2 - 17,
            bottom: 1,
            child: _Finger(_t / 0.55),
          ),
      ],
    );
  }
}
