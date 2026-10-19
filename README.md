# Mehh

귀찮은 사람을 위한 사진 정리 앱 (Flutter). 기획서: [docs/SPEC.md](docs/SPEC.md), 디자인 시안: [docs/design/](docs/design).

## 웹 미리보기

https://itssophie.dev/mehh/ — 브라우저는 사진첩에 접근할 수 없어서, 웹(`kIsWeb`)에서는
샘플 데이터(`lib/data/demo.dart`)로 화면과 동작만 보여준다. 사진 관련 기능은 폰 앱에서만 동작한다.

배포 (서버 `/var/www/mehh-app/`, nginx `location /mehh/`, 다른 서브패스 앱과 같은 방식):

```bash
flutter build web --release --base-href /mehh/
cd build/web && tar czf /tmp/mehh-web.tgz . && scp -i <키> /tmp/mehh-web.tgz ubuntu@168.110.25.49:/tmp/
ssh -i <키> ubuntu@168.110.25.49 'sudo tar xzf /tmp/mehh-web.tgz -C /var/www/mehh-app && rm /tmp/mehh-web.tgz'
```

## 테스트 APK

https://itssophie.dev/mehh/download.html (안내 페이지 `web/download.html`) → `mehh.apk`.
디버그 키로 서명된 arm64 전용 빌드 — 스토어 출시 전 업로드 키로 바꿔야 한다.

```bash
flutter build apk --release --split-per-abi --target-platform android-arm64
scp -i <키> build/app/outputs/flutter-apk/app-arm64-v8a-release.apk ubuntu@168.110.25.49:/tmp/mehh.apk
ssh -i <키> ubuntu@168.110.25.49 'sudo cp /tmp/mehh.apk /var/www/mehh-app/mehh.apk'
```

새 APK를 올리면 `web/download.html`의 버전·크기·SHA-256도 고쳐서 웹과 같이 배포한다.

## 폰트

IBM Plex Sans KR (SIL OFL, `fonts/OFL.txt`) — 4굵기 약 11MB. 앱 용량·웹 로딩이 문제가 되면 서브셋으로 줄인다.
