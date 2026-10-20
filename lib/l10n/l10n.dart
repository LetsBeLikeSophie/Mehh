import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// 화면 문구는 `context.l.키`로 가져온다 (lib/l10n/app_ko.arb·app_en.arb).
extension L10nContext on BuildContext {
  L10n get l => L10n.of(this);
}
