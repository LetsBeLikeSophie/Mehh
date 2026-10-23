/// 앱 버전 (pubspec.yaml version과 같이 고친다). 설정 화면과 문의 메일 제목에 쓴다.
const appVersion = '1.8.3';

/// 설정 > 문의하기 받는 주소. 비어 있으면 문의하기 줄을 숨긴다.
/// 최근 앱에서 다시 열었을 때, 마지막으로 사진을 불러온 지 이만큼 지났으면 새로 불러온다
/// (그 사이 찍은 사진·새 묶음이 보이게, UX 리뷰 2026-10-22)
const reloadLibraryAfter = Duration(minutes: 10);

/// 개인정보처리방침 (web/privacy.html, 스토어 등록 정보에도 같은 주소)
const privacyPolicyUrl = 'https://itssophie.dev/mehh/privacy.html';

const supportEmail = 'hello@itssophie.dev';
