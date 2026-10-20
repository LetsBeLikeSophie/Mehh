# Mehh

귀찮은 사람을 위한 사진 정리 앱 (Flutter). 기준 문서: [docs/SPEC.md](docs/SPEC.md).

## 규칙

- 사진을 킵·보류·정리로 결정하는 화면은 새로 만들지 않고 정리 화면(`SortScreen`)에 종류(`SortKind`)만 추가한다.
  휴대폰 휴지통으로 실제로 보내는 버튼은 어느 화면이든 "휴지통으로"라고 쓴다. 용어는 `lib/ui/strings.dart`의 `Terms`에서 가져온다.
- 색·글자 크기·모서리는 `lib/theme.dart`의 값만 쓰고, 화면에 숫자를 직접 쓰지 않는다.
- 화면이나 기능을 바꾸거나 빼면 같은 커밋에서 `docs/SPEC.md`도 고친다.
