/// 카메라로 찍은 사진·동영상의 폴더인지 (안드로이드). `DCIM/Camera`나 `DCIM/100ANDRO`처럼 기본 카메라가
/// 쓰는 곳이면 true. 경로를 모르면(iOS 등) 지금까지처럼 카메라로 본다.
/// 그 밖은 다른 앱에서 저장·편집·촬영한 것 (2026-11-01 Sophie: 앱별로 쪼개지 않고 한 묶음)
bool isCameraPath(String? path) {
  final parts = (path ?? '')
      .toLowerCase()
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty || parts.contains('camera')) return true;
  return parts.first == 'dcim' &&
      (parts.length == 1 || RegExp(r'^\d{3}').hasMatch(parts[1]));
}

/// 캡처(화면 사진)인지 (2026-10-24 Sophie: 택시 캡처가 사진으로 섞여 이상한 "베스트"가 붙었다).
/// 폴더·파일 이름에 캡처 표시가 있거나, 휴대폰 화면처럼 길쭉하면(긴 변 ≥ 짧은 변 × 2, 짧은 변이
/// 화면 폭 정도) 캡처로 본다. 카메라 사진은 4:3·16:9(1.78)라서 걸리지 않는다.
bool looksLikeScreen({
  required String path,
  required String title,
  required int width,
  required int height,
}) {
  final p = path.toLowerCase();
  final t = title.toLowerCase();
  const words = [
    'screenshot',
    '스크린샷',
    'screen_capture',
    'screencapture',
    'screen capture',
    'capture',
    '캡처',
    'smart select',
    'smartselect',
    'scroll capture',
  ];
  if (words.any((w) => p.contains(w) || t.contains(w))) return true;
  final long = width > height ? width : height;
  final short = width > height ? height : width;
  if (short <= 0) return false;
  return long >= short * screenAspect && short <= screenMaxShortSide;
}

/// 휴대폰 화면 비율 (19.5:9 ≈ 2.17, 20:9 ≈ 2.22). 카메라 16:9 = 1.78은 걸리지 않게 2.0
const screenAspect = 2.0;

/// 화면 캡처의 짧은 변은 화면 폭(보통 1080·1440). 이보다 크면 파노라마 같은 사진으로 본다
const screenMaxShortSide = 1440;
