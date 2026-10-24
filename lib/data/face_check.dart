import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:photo_manager/photo_manager.dart';

/// 눈 감은 컷 찾기 — 폰 안에서만 (Google ML Kit 얼굴 감지, 2026-10-24 Sophie: 추천 근거를 믿을 만하게).
/// 사람을 알아보지 않는다: 얼굴이 있는지와 눈을 떴는지만 보고, 얼굴 정보는 저장하지 않는다.
/// 결과로 남기는 것은 사진마다 "눈 감음" 참·거짓 하나뿐이다.
abstract class FaceChecker {
  /// id → 눈 감은 얼굴이 있다. 못 본 사진은 결과에 넣지 않는다
  Future<Map<String, bool>> eyesClosed(List<String> ids);

  Future<void> close() async {}
}

/// 웹·테스트: 얼굴을 보지 않는다
class NoFaceChecker implements FaceChecker {
  @override
  Future<Map<String, bool>> eyesClosed(List<String> ids) async => const {};

  @override
  Future<void> close() async {}
}

class MlKitFaceChecker implements FaceChecker {
  MlKitFaceChecker(this.entities);

  /// 사진 id → 사진첩 항목 ([PhotoLibrary.entities])
  final Map<String, AssetEntity> entities;

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // 눈 뜬 정도
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.12, // 아주 작은 뒷사람 얼굴은 보지 않는다
    ),
  );

  /// 두 눈 모두 이보다 덜 떴으면 "눈 감음"
  static const closedBelow = 0.25;

  @override
  Future<Map<String, bool>> eyesClosed(List<String> ids) async {
    final out = <String, bool>{};
    final dir = await Directory.systemTemp.createTemp('mehh_faces');
    try {
      for (final id in ids) {
        final e = entities[id];
        if (e == null) continue;
        try {
          final bytes = await e.thumbnailDataWithSize(
            const ThumbnailSize(720, 720),
            quality: 85,
          );
          if (bytes == null) continue;
          final f = File('${dir.path}/$id.jpg');
          await f.writeAsBytes(bytes, flush: true);
          final faces = await _detector.processImage(
            InputImage.fromFilePath(f.path),
          );
          await f.delete();
          out[id] = faces.any((face) {
            final l = face.leftEyeOpenProbability;
            final r = face.rightEyeOpenProbability;
            return l != null && r != null && l < closedBelow && r < closedBelow;
          });
        } catch (err) {
          debugPrint('face check failed: $err');
        }
      }
    } finally {
      await dir.delete(recursive: true);
    }
    return out;
  }

  @override
  Future<void> close() => _detector.close();
}
