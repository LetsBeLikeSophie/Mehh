# 개인정보처리방침 다음 판 초안 (L-1, 2026-11-04)

> 공개 중인 `web/privacy.html`은 그대로 둔다. 이 초안은 Sophie 확인 + 전문가 검토(D3) 뒤 게시한다.
> 지금 방침 1~9장은 그대로 두고 **새 장을 더하거나 바꾸는 부분만** 적었다. `[Sophie 확인]`은 Sophie만 채울 수 있는 값.
> 게시할 때는 CLAUDE.md r26에 따라 앱 두 언어·약관·스토어 메모·SPEC·내려받기 페이지의 같은 약속 문장을 같은 커밋에서 맞춘다.

## 바뀌는 장 순서 (게시본 기준)

1. 운영자 ← 새로
2. 사진첩 접근 (지금 1장, 오류 기록 문장은 D1 안에 따라 바꿈)
3. 휴대폰에만 저장하는 것 (지금 2장)
4. 휴대폰 밖으로 나가는 경우 (지금 3장)
5. 처리 근거 ← 새로
6. 처리 위탁 ← 새로
7. 국외 이전 (지금 4장, "거부 방법과 효과" 문장은 D1 안에 따라 바꿈)
8. 보관 기간과 파기 ← 새로 (문의 메일 보관 포함)
9. 안전성 확보 조치 ← 새로
10. 이용자의 권리와 행사 방법 ← 새로
11. 하지 않는 것 (지금 5장)
12. 삭제한 사진 (지금 6장)
13. 아동 (지금 7장)
14. 권익 침해 구제 ← 새로
15. 바뀌는 경우와 변경 이력 (지금 8장 + 이력 표, L-11)
16. 문의 (지금 9장)

---

## 한국어

### 1. 운영자
- 운영자(개인정보처리자): [Sophie 확인: 실명 또는 Play 개발자 이름 표기 방식] (개인 개발자)
- 개인정보 보호책임자: [Sophie 확인: 이름] · mehh@itssophie.dev
- 주소: [Sophie 확인: 공개할지 — EU 판매 시 Play 판매자 정보로 공개됨, D2]

### 5. 처리 근거
| 처리 | 근거 |
|---|---|
| 사진 분석·정리 추천(휴대폰 안) | 휴대폰 밖으로 나가지 않아 운영자가 개인정보를 받지 않음 |
| 오류 기록(Crashlytics) | [D1-A] 동의(설정에서 끌 수 있음) / [D1-B] 서비스 안정 운영을 위한 정당한 이익·계약 이행 — 추정, 전문가 확인 필요 |
| ML Kit 진단 정보 | 눈 감은 컷 찾기 기능 제공(계약 이행) — 추정 |
| 장소 이름을 위한 위치 좌표 | 장소 이름 붙이기 기능 제공(계약 이행) |
| Cortex로 보내기 | 사용자가 매번 확인 창에서 고르는 동의 |
| 결제 | 계약 이행(Google Play·App Store가 처리) |
| 문의 메일 | 문의에 답하기 위한 동의(사용자가 직접 보냄) |

### 6. 처리 위탁
| 수탁자 | 맡기는 일 | 국가 |
|---|---|---|
| Google LLC (Firebase Crashlytics) | 오류 기록 보관·분석 | 미국 등 |
| Google LLC (ML Kit) | 기능 진단 정보 처리 | 미국 등 |
| Google LLC (Android 위치 서비스) / Apple Inc. (iOS) | 위치 좌표 → 장소 이름 | 미국 등 |
| [Sophie 확인: 메일 서비스 업체] | 문의 메일 보관 | [Sophie 확인] |

결제는 Google Play·App Store가 자기 책임으로 처리하며 위탁이 아닙니다.

### 7. 국외 이전 — "거부 방법과 효과" 문장
- **[D1-A안]** 설정 > [오류 기록 보내기]를 끄면 오류 기록을 더 보내지 않습니다. 앱을 지우면 모든 전송이 멈춥니다. 장소 이름·눈 감은 컷 찾기에 필요한 전송을 거부하려면 앱을 쓸 수 없습니다.
- **[D1-B안]** 앱을 지우면 더 보내지 않습니다. 이전을 거부하면 앱을 쓸 수 없습니다.

(지금의 "이미 보낸 오류 기록은 문의 메일로 지워 달라고 할 수 있습니다"는 두 안 모두 뺀다 — 지킬 방법이 없음, L-2)

### 2장 오류 기록 문장 끝부분
- **[D1-A안]** …오류 기록은 90일 뒤 자동으로 지워집니다. 오류 기록에는 이름·연락처가 없어 운영자가 특정 사용자의 기록을 골라 지울 수 없습니다. 설정 > [오류 기록 보내기]를 끄면 그때부터 보내지 않습니다.
- **[D1-B안]** …오류 기록은 90일 뒤 자동으로 지워집니다. 오류 기록에는 이름·연락처가 없어 운영자가 특정 사용자의 기록을 골라 지울 수 없습니다.

### 8. 보관 기간과 파기
- 휴대폰 안 기록: 사용자가 [모든 기록 지우기]를 누르거나 앱을 지울 때까지. 운영자에게 사본이 없습니다.
- Crashlytics 오류 기록: 90일 뒤 Google이 자동 삭제.
- ML Kit 진단·위치 서비스 요청: Google·Apple의 보관 기준.
- 문의 메일: 답한 날부터 [Sophie 확인: 예 1년] 보관 뒤 삭제. 환불·분쟁 관련 메일은 전자상거래법에 따라 [Sophie 확인: 3년 — 전문가 확인] 보관.
- 파기 방법: 전자 파일은 되살릴 수 없게 삭제합니다. 종이로 남기는 개인정보는 없습니다.

### 9. 안전성 확보 조치
- 운영자는 사용자의 사진·기록을 받는 서버를 두지 않습니다.
- 이용권 상태는 휴대폰의 암호화 저장소(Android Keystore)에 둡니다.
- 앱 기록은 앱 전용 저장 공간에만 두고 클라우드 백업에서 뺍니다.
- 휴대폰 밖으로 가는 전송은 모두 HTTPS로 암호화됩니다.
- 개발 계정(Google Play·Firebase)은 2단계 인증을 쓰고, 운영자 혼자만 접근합니다. [Sophie 확인: 2단계 인증 켜져 있는지]
- 앱 안 오류는 오류 글(파일 경로가 들어갈 수 있음)을 빼고 종류만 보냅니다.

### 10. 이용자의 권리와 행사 방법
- 이용자는 자기 개인정보의 열람·정정·삭제·처리 정지를 요구할 수 있고, EU·영국 이용자는 이의 제기·이동(받아 가기)도 요구할 수 있습니다.
- 휴대폰 안 기록은 설정 > [모든 기록 지우기]로 바로 지울 수 있습니다.
- 그 밖의 요구는 mehh@itssophie.dev로 보내 주세요. 한국은 10일 안에, EU·영국은 1개월 안에 답합니다(복잡하면 이유를 알리고 늘릴 수 있음).
- 오류 기록·진단 정보에는 이름·연락처가 없어 운영자가 누구의 것인지 알 수 없습니다. 그래서 열람·삭제 요구에 응할 수 없는 경우가 있으며, 그때는 그 이유를 알려 드립니다. [D1-A안이면 덧붙임: 설정에서 끄면 그때부터 보내지 않습니다.]
- 대리인(법정대리인 포함)도 위임장을 붙여 요구할 수 있습니다.

### 14. 권익 침해 구제
- 개인정보분쟁조정위원회: 1833-6972, www.kopico.go.kr
- 개인정보침해신고센터(KISA): 국번 없이 118, privacy.kisa.or.kr
- 대검찰청: 1301, www.spo.go.kr / 경찰청: 182, ecrm.police.go.kr
- EU·영국 이용자는 사는 나라의 개인정보 감독기관에 민원을 낼 수 있습니다. (EU 판매 여부는 D2)

### 15. 바뀌는 경우와 변경 이력
이 방침이 바뀌면 이 페이지에 시행일과 함께 알리고, 이용자에게 불리한 변경은 시행 7일 전부터 알립니다. [Sophie 확인: 7일 — 전문가 확인]

| 시행일 | 바뀐 점 |
|---|---|
| 2026-10-?? | 처음 게시 [Sophie 확인: 첫 게시일, git log로 찾을 수 있음] |
| 2026-11-03 | 국외 이전 장 추가, "정리 기록" 문구 |
| [게시일] | 운영자·처리 근거·위탁·보관·안전 조치·권리·구제 장 추가 |

---

## English

### 1. Who we are
- Controller: [Sophie 확인: name as shown on Google Play] (individual developer)
- Privacy contact: [Sophie 확인: name] · mehh@itssophie.dev
- Address: [Sophie 확인 — shown in the Play seller profile if sold in the EU, D2]

### 5. Legal bases
| Processing | Basis |
|---|---|
| Photo analysis and suggestions (on your phone) | Nothing leaves your phone; we receive no personal data |
| Error reports (Crashlytics) | [D1-A] Consent (you can turn it off in Settings) / [D1-B] Legitimate interest in keeping the app stable — to be confirmed by counsel |
| ML Kit diagnostics | Performance of the service (closed-eye check) — to be confirmed |
| Location coordinates for place names | Performance of the service (naming places) |
| Send to Cortex | Your choice in the confirm dialog each time (consent) |
| Purchases | Performance of a contract (handled by Google Play / App Store) |
| Support email | Consent (you send it yourself) |

### 6. Processors
| Processor | Task | Country |
|---|---|---|
| Google LLC (Firebase Crashlytics) | Storing and analyzing error reports | US and others |
| Google LLC (ML Kit) | Processing diagnostics | US and others |
| Google LLC (Android location service) / Apple Inc. (iOS) | Turning coordinates into place names | US and others |
| [Sophie 확인: email provider] | Storing support email | [Sophie 확인] |

Google Play and the App Store handle payments as independent controllers, not as our processors.

### 7. Transfer abroad — "How to refuse"
- **[D1-A]** Turn off Settings > Send error reports to stop error reports. Deleting the app stops all transfers. The transfers needed for place names and the closed-eye check can't be refused while using the app.
- **[D1-B]** Deleting the app stops all transfers. If you refuse the transfer, you can't use the app.

(Remove "You can ask us by email to delete error reports already sent" in both — L-2.)

### Section 2 error-report sentence, ending
- **[D1-A]** …Error reports are deleted automatically after 90 days. They contain no name or contact details, so we can't find and delete a specific person's reports. Turning off Settings > Send error reports stops sending from then on.
- **[D1-B]** …Error reports are deleted automatically after 90 days. They contain no name or contact details, so we can't find and delete a specific person's reports.

### 8. Retention and deletion
- On your phone: until you tap Clear all records or delete the app. We have no copy.
- Crashlytics error reports: deleted automatically by Google after 90 days.
- ML Kit diagnostics and location requests: Google's and Apple's retention rules.
- Support email: kept for [Sophie 확인: e.g. 1 year] after we reply, then deleted. Refund and dispute emails are kept as required by consumer law [Sophie 확인: 3 years in Korea — counsel].
- How: electronic files are deleted so they can't be recovered. We keep no paper records.

### 9. Security
- We run no server that receives your photos or records.
- Plan status is kept in your phone's encrypted storage (Android Keystore).
- App records stay in private app storage and are excluded from cloud backups.
- Everything that leaves your phone is encrypted in transit (HTTPS).
- Developer accounts (Google Play, Firebase) use two-step verification and only the developer has access. [Sophie 확인]
- Errors inside the app are sent by type only, without the message (which could contain a file path).

### 10. Your rights
- You can ask to access, correct, delete or restrict processing of your personal data. In the EU and UK you can also object and ask for portability.
- Records on your phone can be deleted right away with Settings > Clear all records.
- For anything else, email mehh@itssophie.dev. We reply within 10 days in Korea and within one month in the EU/UK (we'll tell you why if we need longer).
- Error reports and diagnostics contain no name or contact details, so we may not be able to tell which are yours. If we can't act on a request for that reason, we'll tell you. [D1-A: You can turn them off in Settings from then on.]
- An authorized representative can make a request with written authorization.

### 14. Complaints
- Korea: Personal Information Dispute Mediation Committee (1833-6972, www.kopico.go.kr), KISA Privacy Center (118, privacy.kisa.or.kr).
- EU/UK: you can complain to the data protection authority where you live. (EU availability: D2)

### 15. Changes and history
We post changes here with the effective date and announce changes that are worse for you at least 7 days in advance. [Sophie 확인: 7 days — counsel]

| Effective | What changed |
|---|---|
| 2026-10-?? | First version [Sophie 확인] |
| 2026-11-03 | Added transfer abroad, "cleanup records" wording |
| [date] | Added controller, legal bases, processors, retention, security, rights and complaints |
