part of '../providers.dart';

// Mehh Pro·코인·결제 대기·잠금

// ───────────────────────── Mehh Pro (SPEC 9장)

final proVaultProvider = Provider<ProVault>(
  (ref) =>
      isDemo || !storeBillingSupported ? MemoryProVault() : SecureProVault(),
);

final billingProvider = Provider<Billing>((ref) {
  final b = isDemo || !storeBillingSupported
      ? DemoBilling(
          korean: PlatformDispatcher.instance.locale.languageCode == 'ko',
        )
      : StoreBilling();
  ref.onDispose(b.dispose);
  return b;
});

class ProNotifier extends AsyncNotifier<ProState> {
  ProVault get _vault => ref.read(proVaultProvider);
  Billing get _billing => ref.read(billingProvider);

  @override
  Future<ProState> build() async {
    final s = await _vault.load();
    _billing.listen(_owned);
    // 결제 대기 중인지 기억한다: 시트를 닫았다 열어도 대기 이야기가 보이게 (UX-64)
    final sub = _billing.status.listen(
      (st) => ref
          .read(billingPendingProvider.notifier)
          .set(st == BillingStatus.pending),
    );
    ref.onDispose(sub.cancel);
    // 1년 이용권이 끝났는지, 다른 폰에서 산 게 있는지 조용히 확인
    Future.microtask(() => restore(quiet: true));
    // 새 달이 됐으면 무료 묶음이 다시 생겼다고 한 번 알린다
    Future.microtask(checkMonth);
    Future.microtask(_checkTestEnded);
    return s;
  }

  /// 비공개 테스트 동안 켠 적이 있는데 이제 테스트가 끝났으면 한 번 알린다 (2026-10-26 Sophie T1-A).
  /// 기록: closedTest 0 = 처음, 1 = 테스트 동안 켬, 2 = 끝났다고 알림
  Future<void> _checkTestEnded() async {
    try {
      final store = ref.read(storeProvider);
      final seen = await store.counter('closedTest');
      if (!ref.mounted) return;
      if (ref.read(closedTestFreeProvider)) {
        if (seen == 0) await store.bumpCounter('closedTest');
      } else if (seen == 1) {
        await store.bumpCounter('closedTest');
        if (ref.mounted) ref.read(testEndedProvider.notifier).raise();
      }
    } catch (_) {
      // 기록을 못 읽으면 알리지 않는다 (돈 상태는 그대로)
    }
  }

  /// 비공개 테스트 동안 [추천 보기]로 본 묶음: 코인 없이 사진만 기억해 둔다.
  /// 테스트가 끝나도 계속 열려 있게 (2026-10-26 Sophie T1-A)
  Future<void> keepOpen(Iterable<String> photoIds) async {
    final s = await future;
    final ids = photoIds.toSet();
    if (s.unlockedPhotos.containsAll(ids)) return;
    await _save(s.copyWith(unlockedPhotos: {...s.unlockedPhotos, ...ids}));
  }

  /// 달이 바뀌어 무료 묶음이 다시 채워졌으면 한 번 알린다 (UX 리뷰 2026-10-23 UX-40).
  /// 앱을 켤 때와 다시 열 때 부른다. 새 달 기록으로 저장해 같은 달에 두 번 뜨지 않는다.
  Future<void> checkMonth({DateTime? now}) async {
    final s = await future;
    final month = monthKey(now ?? DateTime.now());
    if (s.pro ||
        s.freeMonth.isEmpty ||
        s.freeMonth == month ||
        s.freeUsed == 0) {
      return;
    }
    await _save(s.copyWith(freeMonth: month, freeUsed: 0));
    ref.read(freeRefilledProvider.notifier).raise();
  }

  Future<void> _owned(Plan plan) async {
    ref.read(billingPendingProvider.notifier).set(false);
    final s = await future;
    await _save(
      plan == Plan.lifetime
          ? s.copyWith(lifetime: true)
          : s.copyWith(yearly: true),
    );
  }

  /// 스토어에서 가진 것을 다시 받는다. 반환: 복원된 게 있으면 true, 연결 실패면 null.
  /// 평생권은 한 번 받으면 지우지 않는다 (스토어가 잠깐 빈 답을 줘도 사용자가 잃지 않게).
  Future<bool?> restore({bool quiet = false}) async {
    final owned = await _billing.restore();
    if (owned == null) return null;
    final s = await future;
    final next = s.copyWith(
      lifetime: s.lifetime || owned.contains(Plan.lifetime),
      yearly: owned.contains(Plan.yearly),
    );
    if (next.lifetime != s.lifetime || next.yearly != s.yearly) {
      await _save(next);
    }
    // 1년 이용권이 끝나 Pro가 꺼지는 순간 한 번 알린다 (말없이 잠기지 않게, UX 리뷰 2026-10-22)
    if (s.yearly && !next.yearly && !next.lifetime) {
      ref.read(yearlyEndedProvider.notifier).raise();
    }
    return owned.isNotEmpty;
  }

  /// 묶음 추천을 연다. Pro면 그대로, 아니면 이번 달 무료 묶음을 하나 쓴다.
  /// 무료가 다 떨어졌으면 false.
  Future<bool> unlock(
    String groupId, {
    Iterable<String> photoIds = const [],
    DateTime? now,
  }) async {
    final s = await future;
    // Pro로 연 묶음도 사진을 기억해 둔다: 1년 이용권이 끝나도 계속 열려 있게 (2026-10-22 Sophie F3-A)
    if (s.pro) {
      final ids = photoIds.toSet();
      if (!s.unlockedPhotos.containsAll(ids)) {
        await _save(s.copyWith(unlockedPhotos: {...s.unlockedPhotos, ...ids}));
      }
      return true;
    }
    if (s.isOpen(groupId, photoIds: photoIds)) return true;
    final at = now ?? DateTime.now();
    if (s.freeLeft(at) == 0) return false;
    final month = monthKey(at);
    await _save(
      s.copyWith(
        unlocked: {...s.unlocked, groupId},
        unlockedPhotos: {...s.unlockedPhotos, ...photoIds},
        freeMonth: month,
        freeUsed: (s.freeMonth == month ? s.freeUsed : 0) + 1,
      ),
    );
    return true;
  }

  /// 정리를 끝낸 뒤 Pro 안내를 띄울까 (Pro가 아니고 오늘 아직 안 띄웠으면). 띄우면 기록.
  Future<bool> takeNudge({DateTime? now}) async {
    if (!await canNudge(now: now)) return false;
    final s = await future;
    await _save(s.copyWith(lastNudge: _day(now ?? DateTime.now())));
    return true;
  }

  /// [takeNudge]를 쓰지 않고 오늘 안내를 띄울 수 있는지만 본다
  Future<bool> canNudge({DateTime? now}) async {
    if (ref.read(closedTestFreeProvider)) return false; // 테스트 동안은 Pro 안내 없음
    final s = await future;
    final at = now ?? DateTime.now();
    // 무료 묶음을 다 쓴 뒤에만 (무료가 남은 사람에게는 띄우지 않는다, 2026-10-22 Sophie F1-B)
    return !s.pro && s.freeLeft(at) == 0 && s.lastNudge != _day(at);
  }

  static String _day(DateTime at) =>
      '${monthKey(at)}-${at.day.toString().padLeft(2, '0')}';

  Future<void> _save(ProState s) async {
    final was = state.value?.pro ?? false;
    await _vault.save(s);
    state = AsyncData(s);
    // Pro가 켜지는 순간 한 번 알린다: 시트 밖(결제 대기 뒤 완료, 새 폰 조용한 복원)도 (UX-36)
    if (!was && s.pro) ref.read(proStartedProvider.notifier).raise();
  }
}

/// 결제가 대기 중(가족 승인 등). 앱이 켜져 있는 동안만 기억. 산 것이 오거나 실패·취소면 내린다 (UX-64)
class BillingPendingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) => state = v;
}

final billingPendingProvider = NotifierProvider<BillingPendingNotifier, bool>(
  BillingPendingNotifier.new,
);

/// 돈이 걸린 상태가 방금 바뀌었다는 한 번짜리 신호 (홈이 알리고 내린다)
class OneShotNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void raise() => state = true;
  void clear() => state = false;
}

final yearlyEndedProvider = NotifierProvider<OneShotNotifier, bool>(
  OneShotNotifier.new,
);

/// 이번 달 무료 묶음이 방금 다시 생겼다 (홈이 한 번 알리고 내린다)
final freeRefilledProvider = NotifierProvider<OneShotNotifier, bool>(
  OneShotNotifier.new,
);

/// 비공개 테스트가 방금 끝났다 (홈이 "비공개 테스트가 끝났어요 · 이번 달 ◉ 3개"를 한 번 알린다)
final testEndedProvider = NotifierProvider<OneShotNotifier, bool>(
  OneShotNotifier.new,
);

/// Pro가 방금 켜졌다 (홈이 "Pro가 열렸어요"를 한 번 알리고 내린다)
final proStartedProvider = NotifierProvider<OneShotNotifier, bool>(
  OneShotNotifier.new,
);

final proProvider = AsyncNotifierProvider<ProNotifier, ProState>(
  ProNotifier.new,
);

/// 이 묶음의 앱 추천이 열려 있는가 (불러오는 중엔 닫힌 것으로)
/// 비공개 테스트 중 무료 ([closedTestFree]). 테스트에서는 덮어 써서 코인 흐름을 본다
final closedTestFreeProvider = Provider<bool>((ref) => closedTestFree);

final unlockedProvider = Provider.family<bool, DayGroup>(
  (ref, g) =>
      ref.watch(closedTestFreeProvider) ||
      (ref
              .watch(proProvider)
              .value
              ?.isOpen(g.id, photoIds: g.photos.map((p) => p.id)) ??
          false),
);

/// 이 폰에서 아직 잠긴 그날의 묶음과 그 추천 (Pro 안내의 "이 폰에서" 한 줄, 2026-10-26 Sophie P2-A).
/// 이미 계산해 둔 추천만 센다 (새 분석 없음)
final lockedPicksProvider =
    Provider.autoDispose<({int groups, Set<String> ids})>((ref) {
      final lib = ref.watch(libraryProvider).value;
      var groups = 0;
      final ids = <String>{};
      for (final g in lib?.groups ?? const <DayGroup>[]) {
        if (g.kind != DayGroupKind.day || ref.watch(unlockedProvider(g))) {
          continue;
        }
        final plan = ref.watch(groupPlanProvider(g));
        // 정리 화면과 같은 잠금 판단: 돈 드는 추천이 없으면(실수 사진만) 잠기지 않는다
        if (paidPickCount(plan) == 0) continue;
        // 홈에서 "다 봤어요"로 끝낸 묶음은 세지 않는다: 홈과 같은 숫자 (2026-10-28 Sophie P3-A)
        if (ref.watch(groupStatusProvider(g)) == GroupStatus.done) continue;
        groups++;
        // 장수는 정리 화면 [추천 보기 · N장]과 같은 수 (잠긴 추천 + 실수 사진)
        ids.addAll(plan.trash.keys);
      }
      return (groups: groups, ids: ids);
    });
