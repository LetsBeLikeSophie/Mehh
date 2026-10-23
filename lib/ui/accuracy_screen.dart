import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../logic/format.dart';
import '../logic/pick_stats.dart';
import '../logic/recommend.dart';
import '../models/pick.dart';
import '../providers.dart';
import '../theme.dart';
import 'sort_source.dart';
import 'widgets.dart';

/// 숨은 화면: 추천 정확도 (SPEC 6-8). 설정의 버전 글자를 7번 누르면 열린다.
final pickRecordsProvider = FutureProvider.autoDispose<List<PickRecord>>(
  (ref) => ref.read(storeProvider).loadPicks(),
);

class AccuracyScreen extends ConsumerWidget {
  const AccuracyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final locale = Localizations.localeOf(context).toString();
    final records = ref.watch(pickRecordsProvider).value;
    final stats = records == null ? null : PickStats.of(records);
    // 종류별 (그날의 묶음만 유료, 시니어 리뷰 2026-10-23 S-4)
    final byKind = <(String, PickStats)>[
      for (final (kind, name) in [
        ('day', l.kindDay),
        ('singles', l.singles),
        ('screenshots', l.screenshots),
        ('duplicates', l.duplicatesTitle),
      ])
        if (records?.where((r) => r.kind == kind).toList() case final rs?
            when rs.isNotEmpty)
          (name, PickStats.of(rs)),
    ];
    String pct(double? v) => v == null ? '–' : formatPercent(v, locale);
    const muted = TextStyle(
      fontSize: MehhText.caption,
      color: MehhColors.textMuted,
      height: 1.5,
    );
    const row = TextStyle(fontSize: MehhText.bodySmall, height: 1.6);

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
                    l.accTitle,
                    style: const TextStyle(
                      fontSize: MehhText.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (stats == null)
                    const Center(child: CircularProgressIndicator())
                  else if (stats.sends == 0)
                    Text(l.accEmpty, style: muted)
                  else ...[
                    Text(l.accRate, style: muted),
                    Text(
                      pct(stats.acceptRate),
                      style: const TextStyle(
                        fontSize: MehhText.display,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(l.accSends(stats.sends), style: row),
                    Text(
                      l.accAccepted(stats.accepted, stats.suggested),
                      style: row,
                    ),
                    Text(
                      '${l.accAdded(stats.added)} · ${pct(stats.coverage)}',
                      style: row,
                    ),
                    Text('${l.accBest} ${pct(stats.bestRate)}', style: row),
                    if (mutedReasons(stats) case final off when off.isNotEmpty)
                      Text(
                        l.accMuted(
                          [
                            for (final r in off)
                              switch (r) {
                                TrashReason.burst => l.tagBurst,
                                TrashReason.blurry => l.tagBlurry,
                                TrashReason.junk => l.tagJunk,
                              },
                          ].join(', '),
                        ),
                        style: row,
                      ),
                    const SizedBox(height: 20),
                    Text(l.accByKind, style: muted),
                    for (final (name, k) in byKind)
                      Text(
                        '$name  ${l.accTagLine(k.accepted, k.suggested)} · '
                        '${pct(k.acceptRate)}',
                        style: row,
                      ),
                    const SizedBox(height: 20),
                    Text(l.accByTag, style: muted),
                    for (final e in stats.byTag.entries)
                      Text(
                        '${_tagName(e.key, l)}  '
                        '${l.accTagLine(e.value.$1, e.value.$2)} · '
                        '${pct(e.value.$2 == 0 ? null : e.value.$1 / e.value.$2)}',
                        style: row,
                      ),
                  ],
                  const SizedBox(height: 20),
                  Text(l.accNote, style: muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _tagName(String key, L10n l) {
    for (final t in PhotoTag.values) {
      if (t.name == key) return tagText(t, l);
    }
    return '–';
  }
}
