/// 앱 버전 (pubspec.yaml version과 같이 고친다). 설정 화면과 문의 메일 제목에 쓴다.
const appVersion = '1.10.2';

/// 설정 > 문의하기 받는 주소. 비어 있으면 문의하기 줄을 숨긴다.
/// 최근 앱에서 다시 열었을 때, 마지막으로 사진을 불러온 지 이만큼 지났으면 새로 불러온다
/// (그 사이 찍은 사진·새 묶음이 보이게, UX 리뷰 2026-10-22)
const reloadLibraryAfter = Duration(minutes: 10);

/// 홈 막대가 차오르는 시간
const freedBarAnimation = Duration(milliseconds: 700);

/// 크게 보기에서 이만큼 가만히 있으면 "길게 누르면 정리를 끝낼 수 있어요"
const focusIdleHint = Duration(seconds: 5);

/// 그 안내는 하루에 이만큼까지
const focusHintsPerDay = 3;

/// 안내가 떠 있는 시간
const focusHintShown = Duration(seconds: 3);

/// 개인정보처리방침 (web/privacy.html, 스토어 등록 정보에도 같은 주소)
const privacyPolicyUrl = 'https://itssophie.dev/mehh/privacy.html';

const supportEmail = 'hello@itssophie.dev';
