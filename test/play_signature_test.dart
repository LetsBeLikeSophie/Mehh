import 'package:flutter_test/flutter_test.dart';

import 'package:mehh/data/billing.dart';

/// Play 구매 서명 확인이 진짜 서명은 통과시키고 틀린 것은 예외 없이 막는다 (S-3 2026-11-04).
/// 테스트 전용 RSA 2048 키(openssl로 만든 고정값). 실제 playPublicKey는 쓰지 않는다
void main() {
  const key =
      'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAonpX/WML9FZLxbx7'
      'psO4Ln4OqwzmdpBe0aJXLBDlaBpNLXf5+NsOMVLAmpzjQPD1Z0wAKouLHtME'
      'N3UGFXEUwreumeLaU/sNieSCU+cDofUnfGAJTBQsl2EXu3MKooF20KeDSfIN'
      'EbcFHXOaX9G7cuc86Y+KyPGATKfWg5ttDon51VI1xpyhKV9iFbban27X5uV+'
      'yPZ3oyUE4nSvgIk+oexnSxlyIsemQc6TpDp/8ZBY3JsdRAAs6mz9HJUvwcZt'
      'Kpgl0RnsVOp8OSCGrTXRCkZDBnERNeONpLYL1AMgdtDWS6TOuNlqtP2MsHIO'
      'aAcpqQQ8W9BnmkuyP/F/OYw9RQIDAQAB';
  const otherKey =
      'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwcUDXi/TT0Dyk0bX'
      'rDfxV9pLAw42WUhDd0KFtVGXUgQ/PbvRoMUS4e7IFIEBW+wBQB0kZw29W0YZ'
      'I+iMkCT5mNbZMxsDFwbcDfQiYm63LD368NlIo1oTxq5VQUDq3Q4LDPAm8JeB'
      '9q+MiHv5AECkcUCZecWDvB230uMO9CSivNzj+1YoZDx6JhW6YSAJ06itST7g'
      'Dsk0mnaUpSujeCFlnymetDC0LzZ5G6xDeI2FH9Kk3gUsEY9HqFCW5PiLWx/X'
      'DXVVxIYRQUT5SW458U8KGmKiHCHCG6l/tfhvLZGTKZ9akoUCqcYvhGfLHcCx'
      'zbN9+UnRZ/EEOjzTu3jlDioZGwIDAQAB';
  // openssl dgst -sha1 -sign (SHA1withRSA)
  const signature =
      'mNMOYAmn6hrPbmn842xB8fMZL+OILnpR1cv+Rl3jiGdfQ29H9sHWvNbpjgPo'
      'dDgvdBUxrysUwoTM19u709pqBMGnY+uYnUq8Lo9S5hmFiDx6PM0Z4nRvun6n'
      'CIWzwUUjw/ZEJVV+sSCXJBjNy0qFvWPfkE5JCtvrNVBXHA6eRwvjO3daM+vz'
      'pmPFtwzGCCfGOnytdiDm2gVn2VB+RyOBtXFTTaYYi5SCVinOxku7E3yalIiR'
      'ZLBPprkt76doo4eUkoQwJcG3QDQHkfBym/FUrvqKt0RMyvHJMRdVThOjZRc9'
      'EAgvjMAzl3Z5iuIZh5yBonnM6Ahr6Qt9QrH1W1uNwQ==';
  const data =
      r'{"orderId":"GPA.3300-0000-0000-00000","packageName":"dev.itssophie.mehh","productId":"mehh_pro_lifetime","purchaseTime":1767225600000,"purchaseState":0,"purchaseToken":"test-token","quantity":1,"acknowledged":false}';

  test('테스트 키로 서명한 Play 구매 JSON은 통과', () {
    expect(verifyPlaySignature(key, data, signature), isTrue);
  });

  test('데이터 한 글자 바꿈·다른 키·깨진 Base64는 예외 없이 false', () {
    expect(
      verifyPlaySignature(
        key,
        data.replaceFirst('"quantity":1', '"quantity":2'),
        signature,
      ),
      isFalse,
    );
    expect(verifyPlaySignature(otherKey, data, signature), isFalse);
    expect(verifyPlaySignature('not base64!', data, signature), isFalse);
    expect(verifyPlaySignature(key, data, 'not base64!'), isFalse);
    expect(verifyPlaySignature('', data, signature), isFalse);
  });
}
