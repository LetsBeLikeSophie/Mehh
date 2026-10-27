/// 앱 버전 (pubspec.yaml version과 같이 고친다). 설정 화면과 문의 메일 제목에 쓴다.
const appVersion = '1.17.9';

/// 비공개 테스트 동안 그날의 묶음을 코인 없이 모두 연다 (2026-10-24 Sophie). 결제를 켜고 정식 출시할 때 false
const closedTestFree = true;

/// 설정 > 문의하기 받는 주소. 비어 있으면 문의하기 줄을 숨긴다.
/// 최근 앱에서 다시 열었을 때, 마지막으로 사진을 불러온 지 이만큼 지났으면 새로 불러온다
/// (그 사이 찍은 사진·새 묶음이 보이게, UX 리뷰 2026-10-22)
const reloadLibraryAfter = Duration(minutes: 10);

/// 정리 화면에서 이 폭(화면 왼쪽·오른쪽 끝) 안에서 시작한 옆 끌기는 사진 선택 대신 뒤로 가기
const backEdge = 28.0;

/// 그 끌기가 이만큼 안쪽으로 오면 뒤로 간다
const backSwipeDistance = 60.0;

/// 홈 막대가 차오르는 시간
const freedBarAnimation = Duration(milliseconds: 700);

/// 선택한 사진이 있을 때 이만큼 멈추면 "길게 누르면 정리를 끝낼 수 있어요"
const focusIdleHint = Duration(seconds: 3);

/// 길게 누르기로 잡힌 뒤(0.5초) 동그라미가 다 차기까지. 합쳐서 약 1.1초 누르면 "끝낼까요?"
const focusHoldToFinish = Duration(milliseconds: 600);

/// 그 안내는 통틀어 이만큼까지 (길게 누르기를 한 번 쓰면 바로 그만)
const finishHintsTotal = 5;

/// 안내가 떠 있는 시간
const focusHintShown = Duration(seconds: 3);

/// Cortex 스토어 주소. Cortex가 없을 때 [Cortex로]를 누르면 여기로 (비우면 버튼을 숨긴다)
const cortexStoreUrl =
    'https://play.google.com/store/apps/details?id=dev.itssophie.cortex';

/// 개인정보처리방침 (web/privacy.html, 스토어 등록 정보에도 같은 주소)
const privacyPolicyUrl = 'https://itssophie.dev/mehh/privacy.html';

const supportEmail = 'hello@itssophie.dev';
