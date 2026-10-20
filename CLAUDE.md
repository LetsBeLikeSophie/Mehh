# Mehh

귀찮은 사람을 위한 사진 정리 앱 (Flutter). 기준 문서: [docs/SPEC.md](docs/SPEC.md).

## 규칙

- 사진을 킵·정리로 결정하는 화면은 새로 만들지 않고 정리 화면(`SortScreen` 그리드 + `FocusScreen` 크게 보기)에 종류(`SortKind`)만 추가한다.
  휴대폰 휴지통으로 실제로 보내는 버튼은 어느 화면이든 "휴지통으로"(`toTrash`)라고 쓴다.
- 색·글자 크기·모서리는 `lib/theme.dart`의 값만 쓰고, 화면에 숫자를 직접 쓰지 않는다.
- 화면이나 기능을 바꾸거나 빼면 같은 커밋에서 `docs/SPEC.md`도 고친다.
- 화면 문구는 코드에 직접 쓰지 않고 `lib/l10n/app_ko.arb`·`app_en.arb`에 키로 넣어 `context.l.키`로 쓴다(두 파일 같이 고친다). 문장을 조각내 이어붙이지 말고 숫자·이름은 자리표시자(`{count}`)로, 장수는 영어 단수·복수(`plural`)로. 날짜·시간은 `logic/format.dart`(언어별 형식)로만 만든다. 왼쪽·오른쪽 여백은 나중의 오른쪽→왼쪽 언어를 위해 가능하면 `EdgeInsetsDirectional`로.
