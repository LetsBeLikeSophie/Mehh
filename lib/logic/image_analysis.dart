import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/features.dart';

/// 분석할 썸네일 한 장 (Isolate로 넘기기 쉽게 단순한 형태).
class AnalysisInput {
  const AnalysisInput(this.id, this.modifiedAt, this.bytes);
  final String id;
  final int modifiedAt;
  final Uint8List bytes;
}

/// 여러 장을 한 번에 분석한다. `compute`로 백그라운드에서 돌린다.
List<PhotoFeatures> analyzeBatch(List<AnalysisInput> inputs) => [
  for (final i in inputs)
    ?analyzeImage(i.id, i.bytes, modifiedAt: i.modifiedAt),
];

/// 썸네일 바이트 → dHash, 선명도(라플라시안 분산), 평균 밝기.
PhotoFeatures? analyzeImage(String id, Uint8List bytes, {int modifiedAt = 0}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final gray = _gray(decoded);
  final (hi, lo) = dHash(gray);
  return PhotoFeatures(
    id: id,
    hashHi: hi,
    hashLo: lo,
    sharpness: laplacianVariance(gray),
    brightness: meanBrightness(gray),
    contrast: brightnessStdDev(gray),
    textScore: textScore(gray),
    modifiedAt: modifiedAt,
  );
}

/// 흑백 픽셀 (0~255) 2차원 배열
class Gray {
  Gray(this.width, this.height, this.pixels);
  final int width;
  final int height;
  final Uint8List pixels;

  int at(int x, int y) => pixels[y * width + x];
}

Gray _gray(img.Image im) {
  final px = Uint8List(im.width * im.height);
  var i = 0;
  for (final p in im) {
    px[i++] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
  }
  return Gray(im.width, im.height, px);
}

/// 9x8로 줄여 가로로 이웃한 픽셀을 비교한 64bit 해시 → (상위 32bit, 하위 32bit)
(int, int) dHash(Gray g) {
  final small = _resize(g, 9, 8);
  var hi = 0, lo = 0;
  var bit = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final on = small.at(x, y) > small.at(x + 1, y);
      if (on) {
        if (bit < 32) {
          hi |= 1 << (31 - bit);
        } else {
          lo |= 1 << (63 - bit);
        }
      }
      bit++;
    }
  }
  return (hi, lo);
}

/// 영역 평균으로 줄이기
Gray _resize(Gray g, int w, int h) {
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final y0 = y * g.height ~/ h,
        y1 = ((y + 1) * g.height ~/ h).clamp(y0 + 1, g.height);
    for (var x = 0; x < w; x++) {
      final x0 = x * g.width ~/ w,
          x1 = ((x + 1) * g.width ~/ w).clamp(x0 + 1, g.width);
      var sum = 0, n = 0;
      for (var yy = y0; yy < y1; yy++) {
        for (var xx = x0; xx < x1; xx++) {
          sum += g.at(xx, yy);
          n++;
        }
      }
      out[y * w + x] = sum ~/ n;
    }
  }
  return Gray(w, h, out);
}

/// 흔들림 지표: 4방향 라플라시안 값의 분산. 낮을수록 흐리다.
double laplacianVariance(Gray g) {
  if (g.width < 3 || g.height < 3) return 0;
  var sum = 0.0, sumSq = 0.0;
  var n = 0;
  for (var y = 1; y < g.height - 1; y++) {
    for (var x = 1; x < g.width - 1; x++) {
      final v =
          (g.at(x - 1, y) +
                  g.at(x + 1, y) +
                  g.at(x, y - 1) +
                  g.at(x, y + 1) -
                  4 * g.at(x, y))
              .toDouble();
      sum += v;
      sumSq += v * v;
      n++;
    }
  }
  final mean = sum / n;
  return sumSq / n - mean * mean;
}

double meanBrightness(Gray g) {
  var sum = 0;
  for (final p in g.pixels) {
    sum += p;
  }
  return g.pixels.isEmpty ? 0 : sum / g.pixels.length;
}

double brightnessStdDev(Gray g) {
  if (g.pixels.isEmpty) return 0;
  final mean = meanBrightness(g);
  var sq = 0.0;
  for (final p in g.pixels) {
    sq += (p - mean) * (p - mean);
  }
  return math.sqrt(sq / g.pixels.length);
}

/// 글자 화면 점수 (0~1). 배경색이 넓게 깔려 있고(배경 비율),
/// 가로줄마다 짧고 강한 경계가 촘촘하면(글자 줄) 높다. 사진·게임 화면은 낮다.
double textScore(Gray g) {
  if (g.pixels.isEmpty || g.width < 8) return 0;
  final hist = List<int>.filled(256, 0);
  for (final p in g.pixels) {
    hist[p]++;
  }
  var mode = 0;
  for (var v = 1; v < 256; v++) {
    if (hist[v] > hist[mode]) mode = v;
  }
  var bg = 0;
  for (var v = math.max(0, mode - 12); v <= math.min(255, mode + 12); v++) {
    bg += hist[v];
  }
  final bgRatio = bg / g.pixels.length;
  if (bgRatio < 0.4) return 0;

  var textRows = 0;
  for (var y = 0; y < g.height; y++) {
    var edges = 0;
    for (var x = 0; x < g.width - 1; x++) {
      if ((g.at(x + 1, y) - g.at(x, y)).abs() > 35) edges++;
    }
    if (edges >= 6) textRows++;
  }
  return (textRows / g.height).clamp(0, 1).toDouble();
}
