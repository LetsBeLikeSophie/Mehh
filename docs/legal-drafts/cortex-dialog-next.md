# Cortex 보내기 확인 창 다음 문구 초안 (L-5, 2026-11-04)

> 앱 문구는 지금 바꾸지 않는다. CLAUDE.md r26: "폰 밖으로 나가는 것"의 말을 바꾸면 아래 모든 곳을 **같은 커밋**에서 고친다.
> 지금 창(`lib/ui/sort_screen_cortex.dart` 확인 창, 키 `cortexAskNote`): "Cortex에서 AI로 분석해요" / "Cortex analyzes them with AI"

## 창 문구 (화면에 줄글 금지 — 아이콘 + 짧은 줄 2~3개)

| 키(안) | 한국어 | English |
|---|---|---|
| `cortexAskNote` (바꿈) | 사진 파일이 촬영 위치와 함께 Cortex로 가요 | The files go to Cortex, including where they were taken |
| `cortexAskAi` (새로) | Cortex 서버에서 외부 AI(Anthropic, 미국)가 분석해요 | Cortex's server has an outside AI (Anthropic, US) analyze them |
| `cortexAskText` (새로) | 캡처 속 글(계좌·주소·대화)도 함께 가요 | Text inside screenshots (accounts, addresses, chats) goes too |

짧게 한 줄로 줄일 경우: "사진 파일(촬영 위치 포함)이 Cortex 서버의 외부 AI(Anthropic, 미국)로 가요 · 캡처 속 글도 함께" / "Files (with location) go to an outside AI (Anthropic, US) via Cortex's server · text in screenshots too"

[Sophie 확인] Cortex 서버가 사진을 Anthropic에 보내는 범위·보관 기간이 Cortex 처리방침과 같은지 (Cortex 법무 리뷰어 몫).

## 같은 커밋에서 같이 바꿀 곳

1. `lib/l10n/app_ko.arb`, `app_en.arb` — 위 키, 그리고 온보딩·설정의 `privacyCortex`("Cortex로 보낸 사진·캡처는 Cortex에서 AI로 분석해요…")도 "외부 AI(Anthropic, 미국)" 표현으로 맞춤
2. `web/privacy.html` 두 언어 — 3장(4장) "Cortex로 보내기" 줄에 "Cortex 서버에서 Anthropic(미국)의 AI로 분석" + 캡처 속 글, 국외 이전 장에 Cortex 경유 Anthropic 줄(이전받는 자는 Cortex 운영자이고 그 뒤 처리는 Cortex 방침이라는 구분 포함)
3. `docs/store/play-console.md` — 설명의 "사진은 폰 밖으로 안 나감" 문장에 Cortex 예외, 데이터 보안 메모의 Cortex 줄(L-10 공유 신고 여부와 함께)
4. `docs/SPEC.md` — Cortex 보내기 확인 창 줄
5. `web/download.html` — 같은 약속 문장이 있으면
6. 테스트 — 창 문구 테스트(`test/sort_screen_test.dart` Cortex 확인 창), `test/privacy_copy_test.dart`
