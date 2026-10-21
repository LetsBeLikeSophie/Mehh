# Mehh

귀찮은 사람을 위한 사진 정리 앱 (Flutter). 기획서: [docs/SPEC.md](docs/SPEC.md), 디자인 시안: [docs/design/](docs/design).

## 웹 미리보기

https://itssophie.dev/mehh/ — 브라우저는 사진첩에 접근할 수 없어서, 웹(`kIsWeb`)에서는
샘플 데이터(`lib/data/demo.dart`)로 화면과 동작만 보여준다. 사진 관련 기능은 폰 앱에서만 동작한다.

배포 방법은 저장소에 두지 않는다 (서버 주소·명령은 개인 메모에).

## 테스트 APK

https://itssophie.dev/mehh/download.html (안내 페이지 `web/download.html`) → `mehh.apk`.
arm64 전용 빌드. 1.4.0부터 출시용 업로드 키로 서명한다 (`android/key.properties`, git에 안 올림. 키 파일은 따로 백업). key.properties가 없으면 디버그 키로 빌드된다.

새 APK를 올리면 `web/download.html`의 버전·크기·SHA-256도 고쳐서 웹과 같이 배포한다.

## 폰트

IBM Plex Sans KR (SIL OFL, `fonts/OFL.txt`) — 4굵기 약 11MB. 앱 용량·웹 로딩이 문제가 되면 서브셋으로 줄인다.
