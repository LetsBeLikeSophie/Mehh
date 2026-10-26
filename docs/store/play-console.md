# Play Console 준비 (2026-10-25, Mehh 1.17.2)

Sophie가 Play Console에서 그대로 붙여 넣을 수 있게 정리한 문서. 위에서부터 하면 된다.

## 0. 파일

| 무엇 | 파일 | 비고 |
|---|---|---|
| 앱 번들 (AAB) | `build/app/outputs/bundle/release/app-release.aab` | 1.17.2 (60), 출시용 키로 서명 |
| 앱 아이콘 512×512 | `docs/store/icon-512.png` | 흰 바탕 염소 |
| 그래픽 이미지 1024×500 | `docs/store/feature-graphic-ko.png`, `feature-graphic-en.png` | |
| 폰 스크린샷 2~8장 | `docs/store/screenshots-ko/` 5장 (1080×1920) | 에뮬레이터 + 직접 그린 가짜 사진. '테스트 무료'가 보이니 정식 출시 전 다시 찍기 |
| 개인정보처리방침 | https://itssophie.dev/mehh/privacy.html | 한국어·영어 |
| 문의 메일 | hello@itssophie.dev | |

추천 스크린샷 순서 (폰에서 찍기, 사진이 많은 폰이 좋다): ① 홈(정리할 묶음 N개 + 용량 막대) ② 그날의 묶음에서 [추천 보기] 켠 뒤(X와 이유: 비슷한 컷·흔들림·눈 감음) ③ 크게 보기(위 정리·아래 킵) ④ 캡처 추천 ⑤ 큰 동영상 ⑥ 설정의 "사진과 기록은 이 폰에만 있어요".

## 1. 앱 만들기

- 앱 이름: **Mehh**
- 기본 언어: 한국어
- 앱 / 게임: 앱 · 무료 / 유료: **무료** (앱 안에서 이용권 판매)
- 패키지 이름: `dev.itssophie.mehh` (AAB를 올리면 정해짐, 바꿀 수 없음)
- **Play 앱 서명: 사용** (업로드 키는 `C:\Projects\key\mehh-upload.jks`)

## 2. 스토어 등록정보

### 한국어

- 앱 이름 (30자): `Mehh - 귀찮은 사람의 사진 정리`
- 간단한 설명 (80자): `비슷한 컷·흔들린 사진·눈 감은 컷·큰 동영상을 앱이 먼저 골라 둬요. 사진은 폰 밖으로 안 나가요.`
- 자세한 설명:

```
사진첩 정리, 하고는 싶은데 귀찮죠. Mehh가 먼저 골라 둘게요.

■ 그날 단위로 묶어서
여행 하루, 생일 파티처럼 그날 찍은 사진을 한 묶음으로 보여 줘요. 이름도 바꿀 수 있어요.

■ 앱이 먼저 고르고, 나는 확인만
비슷한 연속 컷에서는 확실히 잘 나온 한 장을 남기고, 흔들린 사진·눈 감은 컷·실수로 찍힌 사진·똑같은 사진을 골라 둬요. [추천 보기]를 켜면 X가 쳐지고, 마음에 안 드는 건 X만 끄면 돼요.

■ 손가락 하나로
옆으로 끌면 여러 장을 한 번에 선택하고, 길게 누르면 정리를 끝내요. 크게 보면서 위로 밀면 정리, 아래로 밀면 킵.

■ 큰 동영상과 캡처도
용량 큰 동영상을 크기순으로, 오래된 캡처와 연달아 찍은 캡처를 따로 모아 보여 줘요.

■ 바로 지우지 않아요
[휴지통으로]를 누른 사진만 휴대폰 휴지통으로 가요. 30일 동안 갤러리에서 되살릴 수 있어요.

■ 사진은 폰 밖으로 나가지 않아요
모든 분석(눈 감은 컷 확인 포함)은 휴대폰 안에서 해요. 서버로 사진을 보내지 않고, 클라우드 AI도 쓰지 않아요. 회원 가입도 없어요.

■ 무료로 쓸 수 있는 것
· 똑같은 사진, 낱장 사진, 캡처, 큰 동영상 정리
· 그날의 묶음 추천 매달 3개
· 직접 고르기, 크게 보기

■ Mehh Pro
모든 묶음의 추천 정리를 바로 봐요. 평생 이용권(한 번 구매) 또는 1년 이용권(자동 갱신, 언제든 해지).

문의: hello@itssophie.dev
```

### English

- App name (30): `Mehh: Lazy Photo Cleanup`
- Short description (80): `Mehh picks similar, blurry and eyes-closed shots and big videos. You just check.`
- Full description:

```
You want a tidy photo library, but it's a chore. Mehh does the first pass.

■ One set per day
A trip, a birthday party — each day's photos show up as one set. You can rename it.

■ The app picks, you check
In each burst, Mehh keeps the clearly best shot and marks blurry, eyes-closed, accidental and duplicate photos. Turn on Show picks to mark them, and unmark anything you want to keep.

■ One finger
Drag sideways to select many at once, press and hold to finish. In the large view, swipe up to remove, down to keep.

■ Big videos and screenshots too
See your largest videos by size, plus old and repeated screenshots.

■ Nothing is deleted right away
Only photos you send with Move to trash go to your phone's trash, where you can restore them for 30 days.

■ Your photos never leave your phone
All analysis — including the closed-eye check — happens on your phone. No uploads, no cloud AI, no sign-up.

■ Free
· Duplicates, single shots, screenshots and big videos
· Picks for 3 day sets every month
· Selecting yourself and the large view

■ Mehh Pro
See picks for every set right away. Lifetime (one-time) or 1 year (auto-renews, cancel anytime).

Contact: hello@itssophie.dev
```

- 카테고리: **사진** · 태그: 사진 정리, 갤러리, 저장공간
- 연락처 이메일: hello@itssophie.dev · 웹사이트: https://itssophie.dev/mehh/

## 3. 앱 콘텐츠 설문

| 항목 | 답 |
|---|---|
| 개인정보처리방침 | https://itssophie.dev/mehh/privacy.html |
| 앱 액세스 | 모든 기능을 로그인 없이 쓸 수 있음 (특별한 액세스 필요 없음) |
| 광고 | 광고 없음 |
| 콘텐츠 등급 (IARC) | 카테고리 "유틸리티·생산성" 계열. 폭력·성적 내용·도박·사용자 간 소통·위치 공유 없음 → 전체이용가 예상 |
| 타겟층 | 13세 이상 (아동 대상 아님) — 13~15, 16~17, 18+ 선택 |
| 뉴스 앱 / 정부 앱 / 금융 기능 / 건강 | 아니요 |
| 데이터 보안 | 아래 4번 |
| 사진·동영상 권한 | 아래 5번 |

## 4. 데이터 보안 (Data safety)

- **앱이 사용자 데이터를 수집하거나 공유하나요? → 예 (ML Kit 진단 정보만, 2026-10-25 Sophie)**
  - 수집: **앱 정보 및 성능 > 진단**, **기기 또는 기타 ID** — Google ML Kit(눈 감은 컷)이 진단·사용 통계로 Google에 보낸다. 공유 아님(ML Kit은 제3자에 넘기지 않음), 전송 중 암호화(HTTPS), 필수(끌 수 없음), 목적: 분석. 계정 없음. 사진·얼굴·분석 결과는 보내지 않는다(출처: developers.google.com/ml-kit/android-data-disclosure)
- 그 밖의 데이터: 수집 없음
  - 근거: 사진·분석 결과·킵/정리 기록·정확도 기록은 기기 안에만 저장되고 개발자 서버로 전송되지 않는다. 계정이 없다. 광고 SDK가 없다.
  - Play 기준에서 "수집"은 기기 밖(개발자 또는 제3자)으로 전송되는 것이다. 기기 안에서만 처리하는 것은 수집이 아니다.
- 확인해 둘 것 (설문 중 물어보면):
  - 장소 이름: 사진의 위치 좌표를 휴대폰 OS의 위치 서비스(Geocoder)로 보낸다. 이것은 OS 기능이고 앱이 받는 서버가 없다 → 개인정보처리방침에 적어 둠.
  - 결제: Google Play 결제 시스템이 처리한다 (Play가 공시하는 부분이라 앱 데이터 수집에 넣지 않음).
  - 눈 감은 컷: 폰 안 ML Kit 얼굴 감지로 눈 뜬 정도만 보고, 사진마다 참·거짓 하나만 기기에 남긴다(사람 식별·얼굴 정보 저장·전송 없음) → 수집 아님.
  - Cortex로 보내기: 사용자가 직접 고른 사진·캡처(앱이 추천으로 X 친 사진은 빠짐, 2026-10-26)를 버튼을 눌러 다른 앱(Cortex)으로 넘기는 공유이며(파일의 촬영 위치·시각 EXIF 포함), Mehh가 서버로 보내는 것이 아니다.
- 데이터 암호화: 해당 없음(전송 없음) · 삭제 요청: 앱 안 [모든 기록 지우기] / 앱 삭제

## 5. 사진·동영상 권한 신청서 (READ_MEDIA_IMAGES, READ_MEDIA_VIDEO)

- READ_MEDIA_VIDEO (2026-10-24 추가): "큰 동영상" 정리 — 용량이 큰 동영상을 크기순으로 모아 보여 주고 사용자가 골라 휴지통으로 보낸다. 동영상의 크기·길이·날짜만 읽고 내용은 분석하지 않는다. 사진 정리와 같은 핵심 기능이라 사진 선택기(Photo Picker)로는 "용량 큰 순 전체 목록"을 만들 수 없다.


질문: "앱의 핵심 기능에 사진·동영상에 대한 광범위한 액세스가 필요한 이유"

```
Mehh is a photo-library cleanup app. Its core and only purpose is to review the user's whole photo library and help them delete unwanted photos: it groups every photo by the day and place it was taken, finds exact duplicates and near-identical burst shots across the entire library, detects blurry and accidental photos, and moves the photos the user confirms to the system trash.

These features need to compare every photo with every other photo (for example, finding a duplicate of a photo taken months earlier), so a one-time photo picker or a limited selection cannot provide the core functionality. All analysis runs on the device; no photos or derived data are uploaded.
```

(한국어 요약: 사진첩 전체를 서로 비교해 중복·연속 컷·흔들린 사진을 찾고 정리하는 것이 앱의 유일한 핵심 기능이라, 사진 선택기로는 대신할 수 없다. 분석은 모두 기기 안에서 한다.)

- 데모 영상이 필요하다고 하면: 홈 → 묶음 → [추천 보기] → [휴지통으로] → 갤러리 휴지통에서 확인하는 30초 화면 녹화.
- `ACCESS_MEDIA_LOCATION`: 사진 EXIF 위치로 장소별로 묶기 위해 (기기 위치 권한은 쓰지 않음).

## 6. 출시 국가 (2026-10-24 정리)

- 비공개 테스트: **대한민국**만
- 정식 출시: **모든 국가 − 러시아·벨라루스**(Play 결제 제한). EU에 팔면 판매자(trader) 정보(주소·전화·이메일)가 EU 스토어에 공개되니, 싫으면 처음엔 EU를 빼고 시작
- 판매하면 한국 앱 페이지에 사업자 정보 표시(Play 판매자 프로필)

## 7. 출시 트랙

> 2026-10-25: 비공개 테스트(Alpha) 1.17.2 (60) 검토 제출. 대한민국, 테스터 목록 'Soph'+'테스터 목록'(45명), 의견 hello@itssophie.dev. AI 라벨: 아이콘·그래픽·홈 스크린샷.

1. **비공개 테스트** 트랙 만들기 → 테스터 이메일 목록(12명 이상) → AAB 업로드 → 검토 제출. 테스트 동안은 앱 안에서 그날의 묶음이 무료(`closedTestFree`), 인앱 상품 없어도 됨
2. AAB가 올라가면 **수익 창출 > 인앱 상품**:
   - `mehh_pro_lifetime` 일회성 상품 · ₩12,900 / $9.99
   - `mehh_pro_yearly` 구독 · 1년 · ₩7,900 / $5.99
3. **수익 창출 설정 > 라이선스**의 Base64 공개키를 복사해 개발 세션에 전달 → `playPublicKey`에 넣어 다시 빌드 (그 전 빌드는 결제 버튼이 안 보이는 게 정상)
4. 2023년 11월 이후 만든 개인 계정이면 **비공개 테스트에 테스터 12명 이상, 14일 연속** 후 프로덕션 신청 가능
5. 결제를 켜기 전 SPEC 5단계 "출시 전 결제 체크리스트"를 모두 확인
