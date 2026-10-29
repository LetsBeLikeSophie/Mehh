import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show PurchaseStateWrapper;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';

/// Mehh Pro 상품 (SPEC 9장). Play Console·App Store Connect에 같은 ID로 만든다.
enum Plan {
  /// 평생 이용권 (한 번 사는 상품)
  lifetime('mehh_pro_lifetime'),

  /// 1년 이용권 (자동 갱신 구독)
  yearly('mehh_pro_yearly');

  const Plan(this.productId);
  final String productId;

  /// 지금 파는 상품. 1년 이용권은 산 사람이 있을 때를 위해 복원·끝남 알림만 남긴다
  /// (2026-10-29 Sophie B1-B: 평생권 하나로 시작하고, 첫 4주 전환율을 보고 필요하면 추가)
  static const onSale = [Plan.lifetime];

  static Plan? of(String productId) {
    for (final p in values) {
      if (p.productId == productId) return p;
    }
    return null;
  }
}

class Offer {
  const Offer({required this.plan, required this.price});

  final Plan plan;

  /// 스토어가 알려주는 그 나라 가격 ("₩12,900", "$9.99")
  final String price;
}

/// Play Console > 수익 창출 설정 > 라이선스의 Base64 공개키.
/// 비어 있으면 Play 결제는 모두 거절한다 (가짜 결제 도구 방지, SPEC 9장).
const playPublicKey = '';

enum BillingStatus { pending, canceled, failed, unavailable }

/// 산 것(또는 복원된 것)을 받는 쪽. 저장이 끝나야 스토어에 "전달 완료"를 알린다.
typedef OnOwned = Future<void> Function(Plan plan);

abstract class Billing {
  /// 결제 대기·취소·실패 (화면에 한 줄 안내)
  Stream<BillingStatus> get status;
  Future<List<Offer>> offers();
  Future<void> buy(Offer o);
  void listen(OnOwned onOwned);

  /// 스토어에 지금 가진 것을 묻는다. 연결할 수 없으면 null.
  Future<Set<Plan>?> restore();
  void dispose();
}

/// Google Play / App Store
class StoreBilling implements Billing {
  final _iap = InAppPurchase.instance;
  final _status = StreamController<BillingStatus>.broadcast();
  final _details = <Plan, ProductDetails>{};
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Set<Plan>? _restoring;

  @override
  Stream<BillingStatus> get status => _status.stream;

  @override
  void listen(OnOwned onOwned) {
    _sub ??= _iap.purchaseStream.listen((list) async {
      for (final p in list) {
        final plan = Plan.of(p.productID);
        // 복원은 모든 구매를 restored로 바꿔 보낸다: Play 쪽 상태가 대기면 아직 산 게 아니다 (UX-79)
        final playPending =
            p is GooglePlayPurchaseDetails &&
            p.billingClientPurchase.purchaseState ==
                PurchaseStateWrapper.pending;
        final outcome = purchaseOutcome(
          status: p.status,
          playPending: playPending,
          known: plan != null,
          verified: plan != null && _verified(p),
        );
        switch (outcome) {
          case PurchaseOutcome.pending:
            _status.add(BillingStatus.pending);
          case PurchaseOutcome.canceled:
            _status.add(BillingStatus.canceled);
          case PurchaseOutcome.failed:
            _status.add(BillingStatus.failed);
          case PurchaseOutcome.owned:
            _restoring?.add(plan!);
            await onOwned(plan!);
        }
        // 확인된 구매만 "전달 완료"로 알린다: 확인 실패는 Play가 3일 뒤 자동 환불하고,
        // 대기는 승인되면 다시 온다
        if (shouldComplete(
          pending: p.pendingCompletePurchase,
          verified:
              outcome != PurchaseOutcome.pending &&
              (outcome != PurchaseOutcome.failed ||
                  p.status == PurchaseStatus.error),
        )) {
          await _iap.completePurchase(p);
        }
      }
    }, onError: (_) => _status.add(BillingStatus.failed));
  }

  @override
  Future<List<Offer>> offers() async {
    // 확인할 공개키가 없는 안드로이드 빌드는 결제 버튼을 아예 보이지 않는다
    // (돈은 나갔는데 Pro를 못 받는 일을 막는다, UX 리뷰 2026-10-22)
    if (!canSell(android: defaultTargetPlatform == TargetPlatform.android)) {
      return const [];
    }
    if (!await _iap.isAvailable()) return const [];
    final res = await _iap.queryProductDetails({
      for (final p in Plan.onSale) p.productId,
    });
    for (final d in res.productDetails) {
      if (Plan.of(d.id) case final plan?) _details[plan] = d;
    }
    return [
      for (final plan in Plan.onSale)
        if (_details[plan] case final d?) Offer(plan: plan, price: d.price),
    ];
  }

  @override
  Future<void> buy(Offer o) async {
    final d = _details[o.plan];
    if (d == null) {
      _status.add(BillingStatus.unavailable);
      return;
    }
    // 평생권·구독 모두 "다시 쓰는" 상품이라 buyNonConsumable.
    // 결제 창을 못 띄우면(false·오류) 실패로 알려 버튼이 계속 돌지 않게 (UX-64)
    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: d),
      );
      if (!started) _status.add(BillingStatus.failed);
    } catch (_) {
      _status.add(BillingStatus.failed);
    }
  }

  @override
  Future<Set<Plan>?> restore() async {
    if (!await _iap.isAvailable()) return null;
    final seen = _restoring = <Plan>{};
    try {
      await _iap.restorePurchases();
      // 복원 결과는 purchaseStream으로 따로 온다
      await Future<void>.delayed(const Duration(seconds: 4));
      return seen;
    } catch (_) {
      return null;
    } finally {
      _restoring = null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _status.close();
  }

  bool _verified(PurchaseDetails p) {
    if (p is! GooglePlayPurchaseDetails) return true; // App Store는 StoreKit이 확인
    if (playPublicKey.isEmpty) return false;
    final b = p.billingClientPurchase;
    return verifyPlaySignature(playPublicKey, b.originalJson, b.signature);
  }
}

/// Google Play 구매 서명 확인 (SHA1withRSA, 공개키는 X.509 DER Base64)
bool verifyPlaySignature(String publicKey, String data, String signature) {
  try {
    final spki =
        ASN1Parser(base64Decode(publicKey)).nextObject() as ASN1Sequence;
    final bits = spki.elements![1] as ASN1BitString;
    final rsa =
        ASN1Parser(Uint8List.fromList(bits.stringValues!)).nextObject()
            as ASN1Sequence;
    final key = RSAPublicKey(
      (rsa.elements![0] as ASN1Integer).integer!,
      (rsa.elements![1] as ASN1Integer).integer!,
    );
    final signer = RSASigner(SHA1Digest(), '06052b0e03021a')
      ..init(false, PublicKeyParameter<RSAPublicKey>(key));
    return signer.verifySignature(
      Uint8List.fromList(utf8.encode(data)),
      RSASignature(base64Decode(signature)),
    );
  } catch (_) {
    return false;
  }
}

/// 웹 미리보기·테스트: 결제 흉내만 낸다 (돈이 나가지 않는다)
class DemoBilling implements Billing {
  DemoBilling({required this.korean});

  final bool korean;

  /// 테스트용: 다음 결제를 대기(가족 승인 등)로 / 결제 창 실패로 흉내 낸다
  bool pendingNext = false;
  bool failNext = false;

  /// 테스트용: 복원 때 승인 대기 중인 구매가 하나 있다 (가족 승인 등)
  bool pendingOnRestore = false;
  final _status = StreamController<BillingStatus>.broadcast();
  final owned = <Plan>{};
  OnOwned? _onOwned;

  static const _krw = {Plan.lifetime: '₩12,900', Plan.yearly: '₩7,900'};
  static const _usd = {Plan.lifetime: r'$9.99', Plan.yearly: r'$5.99'};

  @override
  Stream<BillingStatus> get status => _status.stream;

  @override
  void listen(OnOwned onOwned) => _onOwned = onOwned;

  @override
  Future<List<Offer>> offers() async => [
    for (final p in Plan.onSale)
      Offer(plan: p, price: (korean ? _krw : _usd)[p]!),
  ];

  @override
  Future<void> buy(Offer o) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (pendingNext) {
      pendingNext = false;
      _status.add(BillingStatus.pending);
      return;
    }
    if (failNext) {
      failNext = false;
      _status.add(BillingStatus.failed);
      return;
    }
    owned.add(o.plan);
    await _onOwned?.call(o.plan);
  }

  @override
  Future<Set<Plan>?> restore() async {
    // 대기 구매는 산 것으로 돌려주지 않고 대기만 알린다 (UX-79)
    if (pendingOnRestore) _status.add(BillingStatus.pending);
    return {...owned};
  }

  @override
  void dispose() => _status.close();
}

enum PurchaseOutcome { pending, canceled, failed, owned }

/// 스토어가 보낸 구매 하나를 어떻게 받을까. [playPending]은 Play 쪽 구매 상태가 대기인지
/// (복원은 대기 구매도 restored로 보낸다). 대기는 산 것이 아니다 (UX-79 2026-10-28)
PurchaseOutcome purchaseOutcome({
  required PurchaseStatus status,
  required bool playPending,
  required bool known,
  required bool verified,
}) => switch (status) {
  PurchaseStatus.pending => PurchaseOutcome.pending,
  PurchaseStatus.canceled => PurchaseOutcome.canceled,
  PurchaseStatus.error => PurchaseOutcome.failed,
  PurchaseStatus.purchased || PurchaseStatus.restored =>
    playPending
        ? PurchaseOutcome.pending
        : known && verified
        ? PurchaseOutcome.owned
        : PurchaseOutcome.failed,
};

/// 이 빌드에서 팔아도 되는가: 안드로이드는 구매를 확인할 공개키가 있어야 한다
bool canSell({required bool android, String publicKey = playPublicKey}) =>
    !android || publicKey.isNotEmpty;

/// 스토어에 "전달 완료"를 알릴까: 확인된 구매(또는 대기·취소·오류 같은 결제 아닌 것)만
bool shouldComplete({required bool pending, required bool verified}) =>
    pending && verified;

bool get storeBillingSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
