import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/billing.dart';
import '../data/credits.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../theme.dart';
import 'widgets.dart';

/// 크레딧 충전 (SPEC 9장). 회원 가입 없이 스토어 소모성 상품으로 산다.
Future<void> showCreditsSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  backgroundColor: MehhColors.white,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(MehhRadius.card)),
  ),
  builder: (_) => const _CreditsSheet(),
);

class _CreditsSheet extends ConsumerStatefulWidget {
  const _CreditsSheet();

  @override
  ConsumerState<_CreditsSheet> createState() => _CreditsSheetState();
}

class _CreditsSheetState extends ConsumerState<_CreditsSheet> {
  late final Future<List<Pack>> _packs = ref.read(billingProvider).packs();
  StreamSubscription<BillingStatus>? _sub;
  String? _buying;

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

  Future<void> _buy(Pack p) async {
    setState(() => _buying = p.id);
    await ref.read(billingProvider).buy(p);
    // 스토어 결제는 결과가 나중에 온다 (잔액이 늘면 아래 listen에서 알림)
    if (mounted && isDemo) setState(() => _buying = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final balance = ref.watch(creditsProvider).value?.balance ?? 0;
    ref.listen<Credits?>(creditsProvider.select((s) => s.value), (a, b) {
      final added = (b?.balance ?? 0) - (a?.balance ?? 0);
      if (added > 0 && a != null) {
        setState(() => _buying = null);
        showNote(context, l.creditsAdded(added));
      }
    });
    const muted = TextStyle(
      fontSize: MehhText.caption,
      color: MehhColors.textMuted,
      height: 1.5,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l.creditsTitle,
                  style: const TextStyle(
                    fontSize: MehhText.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  l.creditsLeft(balance),
                  style: const TextStyle(
                    fontSize: MehhText.bodySmall,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.creditsBody, style: muted),
            Text(l.creditsFree, style: muted),
            const SizedBox(height: 16),
            FutureBuilder(
              future: _packs,
              builder: (context, snap) {
                final packs = snap.data;
                if (packs == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (packs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(l.billingUnavailable, style: muted),
                  );
                }
                return Column(
                  children: [
                    for (final p in packs) ...[
                      _PackRow(
                        pack: p,
                        busy: _buying == p.id,
                        onTap: _buying == null ? () => _buy(p) : null,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            Text(l.creditsNotes, style: muted),
            if (isDemo) ...[
              const SizedBox(height: 4),
              Text(l.billingDemo, style: muted),
            ],
          ],
        ),
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({required this.pack, required this.busy, this.onTap});

  final Pack pack;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MehhColors.surface,
      borderRadius: BorderRadius.circular(MehhRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(MehhRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                context.l.packCredits(pack.credits),
                style: const TextStyle(
                  fontSize: MehhText.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  pack.price,
                  style: const TextStyle(
                    fontSize: MehhText.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 홈 위쪽 크레딧 칩. 누르면 충전 시트.
class CreditsChip extends ConsumerWidget {
  const CreditsChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(creditsProvider).value?.balance;
    if (balance == null) return const SizedBox.shrink();
    return TextButton(
      onPressed: () => showCreditsSheet(context),
      style: TextButton.styleFrom(
        foregroundColor: MehhColors.text,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(
          fontSize: MehhText.caption,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(context.l.creditsChip(balance)),
    );
  }
}
