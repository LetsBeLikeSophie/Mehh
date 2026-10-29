part of '../providers.dart';

// 사진 접근 권한

// ───────────────────────── 권한

/// 사진 접근 권한. null = 아직 확인 전.
class PermissionNotifier extends Notifier<PermissionState?> {
  @override
  PermissionState? build() {
    _check();
    return null;
  }

  PhotoLibrary get _lib => ref.read(photoLibraryProvider);

  Future<void> _check() async => state = await _lib.permissionState();

  Future<PermissionState> request() async {
    final s = await _lib.requestPermission();
    state = s;
    return s;
  }

  Future<void> openSettings() => _lib.openSettings();

  /// 설정 화면에서 돌아왔을 때 다시 확인
  Future<void> refresh() => _check();
}

final permissionProvider =
    NotifierProvider<PermissionNotifier, PermissionState?>(
      PermissionNotifier.new,
    );
