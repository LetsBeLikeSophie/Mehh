import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import 'config/app_config.dart';
import 'config/cleanup_config.dart';
import 'data/billing.dart';
import 'data/demo.dart';
import 'data/device.dart';
import 'data/face_check.dart';
import 'data/handoff.dart';
import 'data/notices.dart';
import 'data/photo_library.dart';
import 'data/pro.dart';
import 'data/place_namer.dart';
import 'data/sqlite_store.dart';
import 'data/store.dart';
import 'logic/day_grouper.dart';
import 'logic/duplicates.dart';
import 'logic/pick_stats.dart';
import 'logic/recommend.dart';
import 'models/day_group.dart';
import 'models/decision.dart';
import 'models/features.dart';
import 'models/photo_meta.dart';

part 'providers/pro.dart';
part 'providers/permission.dart';
part 'providers/library.dart';
part 'providers/analysis.dart';
part 'providers/decisions.dart';
part 'providers/storage.dart';
part 'providers/cleaner.dart';
part 'providers/plans.dart';
part 'providers/groups.dart';
part 'providers/faces.dart';
part 'providers/status.dart';

/// 웹은 사진첩에 접근할 수 없어 샘플 데이터로 화면만 보여준다.
const isDemo = kIsWeb;

final photoLibraryProvider = Provider<PhotoLibrary>(
  (ref) => isDemo ? DemoPhotoLibrary() : PhotoLibrary(),
);

final placeNamerProvider = Provider<PlaceNamer>(
  (ref) => isDemo
      ? DemoPlaceNamer()
      : PlaceNamer(locale: PlatformDispatcher.instance.locale),
);

final handoffProvider = Provider((ref) => Handoff());

/// Cortex가 설치돼 있으면 캡처를 Cortex로 보낼 수 있다.
/// 앱으로 돌아올 때마다 다시 묻는다: [받으러 가기]로 설치하고 돌아와도 바로 보낼 수 있게 (UX-56)
final cortexInstalledProvider = FutureProvider<bool>((ref) {
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
  return ref.read(handoffProvider).cortexInstalled();
});

final noticesProvider = Provider<Notices>(
  (ref) => isDemo ? DemoNotices(supported: false) : PhoneNotices(),
);

/// 매달 알림이 켜져 있나 (B2-B). 폰 설정에서 끌 수도 있어 앱으로 돌아올 때마다 다시 본다
final monthlyNoticeProvider = FutureProvider<bool>((ref) {
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
  return ref.read(noticesProvider).isOn();
});

final storeProvider = Provider<Store>(
  (ref) => isDemo ? MemoryStore() : SqliteStore(),
);
