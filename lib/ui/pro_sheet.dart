import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/billing.dart';
import '../data/pro.dart';
import '../l10n/l10n.dart';
import '../logic/format.dart';
import '../logic/recommend.dart';
import '../models/day_group.dart';
import '../providers.dart';
import '../theme.dart';
import 'sort_screen.dart';
import 'widgets.dart';

/// Mehh Pro 안내 (SPEC 9장): 평생 이용권 / 1년 이용권 / 구매 복원.
/// [lead]는 정리를 끝낸 직후에 띄울 때 맨 위 한 줄.
Future<void> showProSheet(BuildContext context, {String? lead}) =>
    showModalBottomSheet(
      context: context,
      backgroundColor: MehhColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MehhRadius.card),
        ),
      ),
      builder: (_) => _ProSheet(lead: lead),
    );

class _ProSheet extends ConsumerStatefulWidget {
  const _ProSheet({this.lead});

  final String? lead;

  @override
  ConsumerState<_ProSheet> createState() => _ProSheetState();
}

class _ProSheetState extends ConsumerState<_ProSheet> {
  late final Future<List<Offer>> _offers = ref.read(billingProvider).offers();
  StreamSubscription<BillingStatus>? _sub;
  Plan? _buying;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(billingProvider).status.listen((s) {
      if (!mounted) return;
      final l = context.l;
      setState(() => _buying = null);
      switch (s) {
        case BillingStatus.pending:
          showNote(context, l.billingPending);
        case BillingStatus.failed:
          showNote(context, l.billingFailed);
        case BillingStatus.unavailable:
          showNote(context, l.billingUnavailable);
        case BillingStatus.canceled:
          break;
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _buy(Offer o) async {
    setState(() => _buying = o.plan);
    await ref.read(billingProvider).buy(o);
    // 스토어 결제는 결과가 나중에 온다 (Pro가 되면 아래 listen에서 닫힘)
    if (mounted && isDemo) setState(() => _buying = null);
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final found = await ref.read(proProvider.notifier).restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    final l = context.l;
    showNote(context, switch (found) {
      null => l.billingUnavailable,
      true => l.restored,
      false => l.nothingToRestore,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pro = ref.watch(proProvider).value ?? const ProState();
    ref.listen<bool>(proProvider.select((s) => s.value?.pro ?? false), (
      was,
      now,
    ) {
      // 알림은 홈이 한 번만 띄운다 (proStartedProvider). 시트는 닫기만
      if (now && was == false) Navigator.of(context).maybePop();
    });
    const muted = TextStyle(
      fontSize: MehhText.caption,
      color: MehhColors.textMuted,
      height: 1.5,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.lead case final lead?) ...[
              Text(
                lead,
                style: const TextStyle(
                  fontSize: MehhText.body,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              l.proTitle,
              style: const TextStyle(
                fontSize: MehhText.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (pro.pro)
              Text(l.proActive, style: muted)
            else ...[
              Text(l.proBody, style: muted),
              Text(
                l.proFree(
                  freeGroupsPerMonth,
                  pro.freeLeft(DateTime.now()),
                  formatDate(nextFreeReset(DateTime.now()), l.localeName),
                ),
                style: muted,
              ),
              // 무료 종류 추천은 Pro 없이도 늘 무료 (UX-37)
              Text(l.proFreeKinds, style: muted),
              // 무료를 다 썼으면 지금 무료로 할 수 있는 일을 하나 보여 준다 (Sophie P1-A)
              if (pro.freeLeft(DateTime.now()) == 0) const _FreeTodo(),
              const SizedBox(height: 16),
              FutureBuilder(
                future: _offers,
                builder: (context, snap) {
                  final offers = snap.data;
                  if (offers == null) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (offers.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(l.billingUnavailable, style: muted),
                    );
                  }
                  return Column(
                    children: [
                      for (final o in offers) ...[
                        _OfferRow(
                          offer: o,
                          busy: _buying == o.plan,
                          onTap: _buying == null ? () => _buy(o) : null,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 4),
            Text(l.proNotes, style: muted),
            if (isDemo) Text(l.billingDemo, style: muted),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _restoring ? null : _restore,
                style: TextButton.styleFrom(
                  foregroundColor: MehhColors.text,
                  minimumSize: const Size(44, 44),
                ),
                child: Text(l.restorePurchases),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer, required this.busy, this.onTap});

  final Offer offer;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final best = offer.plan == Plan.lifetime;
    final (name, note) = switch (offer.plan) {
      Plan.lifetime => (l.planLifetime, l.planLifetimeNote),
      Plan.yearly => (l.planYearly, l.planYearlyNote),
    };
    final fg = best ? MehhColors.white : MehhColors.text;
    return Material(
      color: best ? MehhColors.black : MehhColors.surface,
      borderRadius: BorderRadius.circular(MehhRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(MehhRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: MehhText.body,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                        if (best) ...[
                          const SizedBox(width: 6),
                          MehhBadge(l.planBest, inverted: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: MehhText.caption,
                        color: best
                            ? MehhColors.onBlackMuted
                            : MehhColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else
                Text(
                  offer.price,
                  style: TextStyle(
                    fontSize: MehhText.body,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 홈 위쪽 칩: Pro면 "Pro", 아니면 이번 달 남은 무료 묶음. 누르면 Pro 안내.
class ProChip extends ConsumerWidget {
  const ProChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(proProvider).value;
    if (s == null) return const SizedBox.shrink();
    final l = context.l;
    // 비공개 테스트 동안은 코인 대신 "테스트 무료"
    if (ref.watch(closedTestFreeProvider)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          l.testFreeChip,
          style: const TextStyle(
            fontSize: MehhText.caption,
            fontWeight: FontWeight.w600,
            color: MehhColors.textMuted,
          ),
        ),
      );
    }
    return TextButton(
      onPressed: () => showProSheet(context),
      style: TextButton.styleFrom(
        foregroundColor: MehhColors.text,
        minimumSize: const Size(44, 44),
        // 옆 아이콘과 가깝게 (2026-10-24 Sophie)
        padding: const EdgeInsets.symmetric(horizontal: 6),
        // textStyle을 바꾸면 테마 글꼴이 빠지므로 글꼴도 같이 준다
        textStyle: const TextStyle(
          fontFamily: mehhFontFamily,
          fontSize: MehhText.caption,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: s.pro
          ? Text(l.proChip)
          : CoinCount(s.freeLeft(DateTime.now()), size: 22),
    );
  }
}

/// Pro 안내에서 "지금 무료로 할 수 있는 일" 한 줄: 캡처 추천과 똑같은 사진 중 많은 쪽 (P1-A)
class _FreeTodo extends ConsumerWidget {
  const _FreeTodo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final groups = ref.watch(libraryProvider).value?.groups ?? const [];
    final decisions = ref.watch(decisionsProvider).value ?? const {};
    final shots = [
      for (final g in groups)
        if (g.kind == DayGroupKind.screenshots) g,
    ].firstOrNull;
    final shotPicks = shots == null
        ? 0
        : planScreenshots(
            shots.photos,
            ref.watch(analysisProvider.select((a) => a.features)),
            decisions,
            now: DateTime.now(),
          ).length;
    final dups = duplicatesLeft(ref.watch(duplicatesProvider).value, decisions);
    if (shotPicks == 0 && dups == 0) return const SizedBox.shrink();
    final useShots = shotPicks >= dups;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: () {
          final nav = Navigator.of(context);
          nav.pop();
          nav.push(
            useShots
                ? sortRoute(SortKind.screenshots, group: shots)
                : sortRoute(SortKind.duplicates),
          );
        },
        style: TextButton.styleFrom(
          foregroundColor: MehhColors.text,
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
        ),
        child: Text(
          useShots ? l.freeTodoShots(shotPicks) : l.freeTodoDuplicates(dups),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
