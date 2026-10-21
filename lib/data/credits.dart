import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 크레딧 (SPEC 9장). 회원 가입 없이 이 폰에만 저장한다.
///
/// - 잔액과 기록은 Android Keystore로 암호화한 저장소에 둔다 (flutter_secure_storage).
/// - 같은 구매를 두 번 더하지 않도록 구매 번호를 기억한다.
/// - 루팅·후킹까지는 막지 않는다 (docs/ideas.md "크레딧 메모").
class Credits {
  const Credits({
    this.balance = 0,
    this.unlocked = const {},
    this.purchases = const {},
    this.welcomeGiven = false,
  });

  final int balance;

  /// 크레딧을 써서 추천을 연 묶음 (한 번 열면 계속 열려 있다)
  final Set<String> unlocked;

  /// 이미 더한 구매 번호
  final Set<String> purchases;

  /// 처음 받는 무료 크레딧을 줬는가
  final bool welcomeGiven;

  Credits copyWith({
    int? balance,
    Set<String>? unlocked,
    Set<String>? purchases,
    bool? welcomeGiven,
  }) => Credits(
    balance: balance ?? this.balance,
    unlocked: unlocked ?? this.unlocked,
    purchases: purchases ?? this.purchases,
    welcomeGiven: welcomeGiven ?? this.welcomeGiven,
  );

  Map<String, Object> toJson() => {
    'balance': balance,
    'unlocked': unlocked.toList(),
    'purchases': purchases.toList(),
    'welcomeGiven': welcomeGiven,
  };

  factory Credits.fromJson(Map<String, dynamic> j) => Credits(
    balance: j['balance'] as int? ?? 0,
    unlocked: {...(j['unlocked'] as List? ?? const []).cast<String>()},
    purchases: {...(j['purchases'] as List? ?? const []).cast<String>()},
    welcomeGiven: j['welcomeGiven'] as bool? ?? false,
  );
}

/// 처음 설치하면 주는 무료 크레딧
const welcomeCredits = 5;

/// 크레딧 1개로 묶음 하나의 추천을 연다
const unlockCost = 1;

abstract class CreditVault {
  Future<Credits> load();
  Future<void> save(Credits c);
}

/// 실제 앱: Keystore로 암호화한 저장소. 클라우드 백업에는 넣지 않는다.
class SecureCreditVault implements CreditVault {
  static const _key = 'mehh.credits.v1';
  final _storage = const FlutterSecureStorage();

  @override
  Future<Credits> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return const Credits();
      return Credits.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const Credits();
    }
  }

  @override
  Future<void> save(Credits c) =>
      _storage.write(key: _key, value: jsonEncode(c.toJson()));
}

/// 웹 미리보기·테스트용. 앱을 끄면 사라진다.
class MemoryCreditVault implements CreditVault {
  MemoryCreditVault([this.value = const Credits()]);
  Credits value;

  @override
  Future<Credits> load() async => value;

  @override
  Future<void> save(Credits c) async => value = c;
}
