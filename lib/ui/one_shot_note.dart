import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'widgets.dart';

/// 한 번짜리 신호가 오르면 한 줄로 알리고 내린다. build에서 부른다.
/// 여러 화면이 같은 신호를 들어도 먼저 본 화면이 내리므로 한 번만 보인다.
/// 신호가 이미 올라 있으면(온보딩 동안 등) 처음 그릴 때 보인다 (UX-107)
void noteOnSignal(
  WidgetRef ref,
  BuildContext context,
  NotifierProvider<OneShotNotifier, bool> signal,
  String text,
) {
  void show() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted || !ref.read(signal)) return;
    ref.read(signal.notifier).clear();
    showNote(context, text);
  });
  ref.listen(signal, (_, raised) {
    if (raised) show();
  });
  if (ref.read(signal)) show();
}
