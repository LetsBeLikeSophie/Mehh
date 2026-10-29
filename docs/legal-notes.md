# 법적 검토 메모: 기기 안 학습·분석 (2026-10-19)

> 공개 자료를 찾아 정리한 메모이고 법률 자문이 아니다. 출시 전 전문가 검토 필요 (SPEC 10장).

## 결론

- 사진 분석·결정 기록·취향 학습을 **기기 안에서만** 하고 개발자 서버로 보내지 않으면,
  주요 스토어 기준과 미국 판례상 "수집"으로 보지 않는다. 글로벌 출시에서도 위험이 낮은 구조.
- 클라우드 AI(사진을 외부 API로 전송)는 이번 버전에서 하지 않는다.
- 남은 주의점: ML Kit 사용 통계, 안드로이드 자동 백업, 얼굴 정보 저장 금지, 투명한 안내.

## 근거

### Apple App Store
- "Collect" = 데이터를 기기 밖으로 전송해 실시간 처리에 필요한 시간보다 오래 접근할 수 있게 하는 것.
- **기기 안에서만 처리하는 데이터는 "수집"이 아니며 신고하지 않아도 된다.**
  다만 거기서 파생한 값을 기기 밖으로 보내면 그 값은 따로 따진다.
- 출처: https://developer.apple.com/app-store/app-privacy-details/

### Google Play
- "Collect" = 앱에서 기기 밖으로 데이터를 전송하는 것.
- 권한으로 얻은 데이터를 기기 안 기능에만 쓰고 서버로 보내지 않으면 수집으로 신고하지 않아도 된다.
- 단, 기기 안에서라도 **다른 앱으로 넘기면** "공유"로 신고해야 한다.
- Data safety 양식 자체는 수집이 없어도 제출한다.
- 출처: https://support.google.com/googleplay/android-developer/answer/10787469

### 미국 일리노이 BIPA (생체정보)
- Barnett v. Apple (2022 IL App (1st) 220187): Face ID·Touch ID 데이터가 기기 안에만 있고
  Apple 서버로 가지 않으므로 Apple이 수집·보유한 것이 아니라고 보고 소송 기각을 확정.
- → 기기 안 얼굴 **감지**는 위험이 낮다. 그래도 얼굴 특징점·임베딩을 저장하거나
  사람별로 묶는 기능은 하지 않는다 (SPEC 10장과 같음).
- 일리노이 대법원 상고 여부는 확인하지 못함.
- 출처: https://www.americanbar.org/groups/antitrust_law/resources/newsletters/barnett-v-apple-privacy-by-design/ ,
  https://blogs.duanemorris.com/classactiondefense/2023/01/09/illinois-appellate-court-affirms-dismissal-of-bipa-class-action-lawsuit/

### EU GDPR
- 기기 안 처리만 하고 개발자가 접근할 수 없으면 개발자의 의무가 크게 줄어든다는 실무 해석이 있으나,
  이를 직접 정한 EDPB 지침·판결은 찾지 못했다. → 개인정보처리방침에 기기 안 처리임을 명시하고,
  데이터 최소화·삭제 기능을 갖춘다 (Article 25 프라이버시 바이 디자인).
- 출처: https://www.algoodbody.com/media/Developingmobileappshowtobeprivacysavvy1.pdf

### 미국 캘리포니아 CCPA
- "collects" 정의가 넓다 (buying, renting, gathering, obtaining, receiving, accessing).
  기기 안에서만 처리하는 경우를 직접 다룬 자료는 찾지 못함 → 전문가 확인 항목.
- 출처: https://www.morganlewis.com/pubs/2019/12/practical-advice-on-privacy-the-ccpa-impacts-non-us-companies-are-you-prepared

### Google ML Kit (4단계에서 쓸 예정)
- 이미지 등 입력과 결과는 기기 안에서 처리되고 Google 서버로 가지 않는다.
- 하지만 **API 성능·사용 통계는 Google로 전송**되고, 모델 업데이트를 받으러 서버에 접속할 수 있다.
- 개발자는 현지 법이 요구하면 이 통계 처리를 사용자에게 알려야 하고, Play 데이터 공개 요건을 따라야 한다.
- → ML Kit을 넣으면 "수집 데이터 없음"이 그대로 유지되는지 Play 양식에서 다시 확인할 것.
- 출처: https://developers.google.com/ml-kit/terms

## 앱에서 할 일

- [x] 안드로이드 자동 백업에서 앱 데이터(DB·캐시) 제외 — 기본값이면 사용자 Google Drive로 백업된다.
- [x] 설정에 "모든 기록 지우기" (분석 결과·결정 기록·위치/장소 캐시 삭제. 열람 기록은 1.17.14부터 남기지 않고 남아 있던 것도 지움).
- [x] 온보딩 문구: "고를수록 취향을 배워요. 기록은 이 폰에만 남아요."
- [ ] 개인정보처리방침: 사진·학습 기록은 기기에만 저장, 장소 이름 조회 때 좌표가 OS 지오코더로 전달될 수 있음.
- [ ] 저장하는 학습 특징은 식별 불가능한 값만 (선명도, 밝기, 종류 라벨, 얼굴 수, 연속 컷 크기, 결정).
- [ ] 4단계 ML Kit 도입 시 통계 전송 고지 여부 확인.
- [ ] iOS 빌드 때 DB·캐시 파일을 iCloud 백업에서 제외 (isExcludedFromBackup).

## 전문가에게 물어볼 것

1. 기기 안 처리만 하는 앱이 GDPR상 컨트롤러 의무(처리방침 외)를 얼마나 지는지.
2. CCPA "collect"에 기기 안 처리가 포함되는지.
3. ML Kit 사용 통계가 Play Data safety·Apple 개인정보 라벨에서 신고 대상인지.
4. 한국 개인정보보호법상 별도 고지·동의가 필요한 항목이 있는지 (지오코더 좌표 전달 포함).
