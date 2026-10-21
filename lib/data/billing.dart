import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';

/// 크레딧 묶음 상품 (스토어 소모성 상품, SPEC 9장)
class Pack {
  const Pack({required this.id, required this.credits, required this.price});

  final String id;
  final int credits;

  /// 스토어가 알려주는 그 나라 가격 ("₩1,900", "$1.49")
  final String price;
}

/// 상품 ID → 크레딧 수. Play Console·App Store Connect에 같은 ID로 만든다.
const packCredits = {
  'mehh_credits_10': 10,
  'mehh_credits_30': 30,
  'mehh_credits_100': 100,
};

/// Play Console > 수익 창출 설정 > 라이선스의 Base64 공개키.
/// 비어 있으면 Play 결제는 모두 거절한다 (가짜 결제 도구 방지, SPEC 9장).
const playPublicKey = '';

enum BillingStatus { pending, canceled, failed, unavailable }

/// 결제가 끝나면 크레딧을 더하는 쪽. 저장이 끝나야 스토어에 "전달 완료"를 알린다.
typedef OnPurchased = Future<void> Function(String purchaseId, int credits);

abstract class Billing {
  /// 결제 대기·취소·실패 (화면에 한 줄 안내)
  Stream<BillingStatus> get status;
  Future<List<Pack>> packs();
  Future<void> buy(Pack p);
  void listen(OnPurchased onPurchased);
  void dispose();
}

/// Google Play / App Store
class StoreBilling implements Billing {
  final _iap = InAppPurchase.instance;
  final _status = StreamController<BillingStatus>.broadcast();
  final _details = <String, ProductDetails>{};
  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  Stream<BillingStatus> get status => _status.stream;

  @override
  void listen(OnPurchased onPurchased) {
    _sub ??= _iap.purchaseStream.listen((list) async {
      for (final p in list) {
        switch (p.status) {
          case PurchaseStatus.pending:
            _status.add(BillingStatus.pending);
          case PurchaseStatus.canceled:
            _status.add(BillingStatus.canceled);
          case PurchaseStatus.error:
            _status.add(BillingStatus.failed);
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            final credits = packCredits[p.productID];
            if (credits != null && _verified(p)) {
              await onPurchased(
                p.purchaseID ?? p.transactionDate ?? '',
                credits,
              );
            } else {
              _status.add(BillingStatus.failed);
            }
        }
        if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      }
    }, onError: (_) => _status.add(BillingStatus.failed));
  }

  @override
  Future<List<Pack>> packs() async {
    if (!await _iap.isAvailable()) return const [];
    final res = await _iap.queryProductDetails(packCredits.keys.toSet());
    for (final d in res.productDetails) {
      _details[d.id] = d;
    }
    return [
      for (final id in packCredits.keys)
        if (_details[id] case final d?)
          Pack(id: id, credits: packCredits[id]!, price: d.price),
    ];
  }

  @override
  Future<void> buy(Pack p) async {
    final d = _details[p.id];
    if (d == null) {
      _status.add(BillingStatus.unavailable);
      return;
    }
    await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: d));
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

/// 웹 미리보기: 결제 흉내만 낸다 (돈이 나가지 않는다)
class DemoBilling implements Billing {
  DemoBilling({required this.korean});

  final bool korean;
  final _status = StreamController<BillingStatus>.broadcast();
  OnPurchased? _onPurchased;
  var _n = 0;

  static const _krw = {10: '₩1,900', 30: '₩4,400', 100: '₩9,900'};
  static const _usd = {10: r'$1.49', 30: r'$2.99', 100: r'$6.99'};

  @override
  Stream<BillingStatus> get status => _status.stream;

  @override
  void listen(OnPurchased onPurchased) => _onPurchased = onPurchased;

  @override
  Future<List<Pack>> packs() async => [
    for (final e in packCredits.entries)
      Pack(
        id: e.key,
        credits: e.value,
        price: (korean ? _krw : _usd)[e.value]!,
      ),
  ];

  @override
  Future<void> buy(Pack p) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _onPurchased?.call('demo-${_n++}', p.credits);
  }

  @override
  void dispose() => _status.close();
}

bool get storeBillingSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
