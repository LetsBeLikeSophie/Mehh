import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'store.dart';

/// 무료로 추천을 볼 수 있는 그날의 묶음 수 (매달 1일에 다시 채워진다)
const freeGroupsPerMonth = 3;

/// Mehh Pro와 무료 묶음 (SPEC 9장). 회원 가입 없이 이 폰에 저장하고,
/// 산 것은 스토어 [구매 복원]으로 다시 받는다.
class ProState {
  const ProState({
    this.lifetime = false,
    this.yearly = false,
    this.unlocked = const {},
    this.freeMonth = '',
    this.freeUsed = 0,
    this.lastNudge = '',
  });

  /// 평생 이용권
  final bool lifetime;

  /// 1년 이용권 (마지막으로 스토어에 확인했을 때 살아 있었다)
  final bool yearly;

  /// 무료로 추천을 연 묶음 (한 번 열면 계속 열려 있다)
  final Set<String> unlocked;

  /// [freeUsed]를 센 달 ('yyyy-MM')
  final String freeMonth;
  final int freeUsed;

  /// 정리 끝난 뒤 Pro 안내를 마지막으로 띄운 날 ('yyyy-MM-dd', 하루 한 번까지)
  final String lastNudge;

  bool get pro => lifetime || yearly;

  int freeLeft(DateTime now) => freeMonth == monthKey(now)
      ? (freeGroupsPerMonth - freeUsed).clamp(0, freeGroupsPerMonth)
      : freeGroupsPerMonth;

  bool isOpen(String groupId) => pro || unlocked.contains(groupId);

  ProState copyWith({
    bool? lifetime,
    bool? yearly,
    Set<String>? unlocked,
    String? freeMonth,
    int? freeUsed,
    String? lastNudge,
  }) => ProState(
    lifetime: lifetime ?? this.lifetime,
    yearly: yearly ?? this.yearly,
    unlocked: unlocked ?? this.unlocked,
    freeMonth: freeMonth ?? this.freeMonth,
    freeUsed: freeUsed ?? this.freeUsed,
    lastNudge: lastNudge ?? this.lastNudge,
  );

  Map<String, Object> toJson() => {
    'lifetime': lifetime,
    'yearly': yearly,
    'unlocked': unlocked.toList(),
    'freeMonth': freeMonth,
    'freeUsed': freeUsed,
    'lastNudge': lastNudge,
  };

  factory ProState.fromJson(Map<String, dynamic> j) => ProState(
    lifetime: j['lifetime'] as bool? ?? false,
    yearly: j['yearly'] as bool? ?? false,
    unlocked: {...(j['unlocked'] as List? ?? const []).cast<String>()},
    freeMonth: j['freeMonth'] as String? ?? '',
    freeUsed: j['freeUsed'] as int? ?? 0,
    lastNudge: j['lastNudge'] as String? ?? '',
  );
}

abstract class ProVault {
  Future<ProState> load();
  Future<void> save(ProState s);
}

/// 실제 앱: Keystore로 암호화한 저장소. 클라우드 백업에는 넣지 않는다
/// (산 것은 스토어가 복원해 준다).
class SecureProVault implements ProVault {
  static const _key = 'mehh.pro.v1';
  final _storage = const FlutterSecureStorage();

  @override
  Future<ProState> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return const ProState();
      return ProState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ProState();
    }
  }

  @override
  Future<void> save(ProState s) =>
      _storage.write(key: _key, value: jsonEncode(s.toJson()));
}

/// 웹 미리보기·테스트용. 앱을 끄면 사라진다.
class MemoryProVault implements ProVault {
  MemoryProVault([this.value = const ProState()]);
  ProState value;

  @override
  Future<ProState> load() async => value;

  @override
  Future<void> save(ProState s) async => value = s;
}
