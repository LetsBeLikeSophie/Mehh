import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// 알림 글 (제목, 내용, 폰 설정에 보이는 알림 종류 이름)
typedef NoticeText = ({String title, String body, String channel});

/// 한 달에 한 번 알림 (2026-10-29 Sophie B2-B). 사용자가 허락하면 매달 1일 낮 12시쯤 한 번.
/// 폰 안에서만 예약하고, 밖으로 보내는 것은 없다.
abstract class Notices {
  /// 이 폰에서 알림을 보일 수 있나 (안드로이드만). 아니면 묻지도 않는다
  bool get supported;

  /// 켜져 있나: 예약이 있고 폰 설정에서 알림이 허락돼 있다
  Future<bool> isOn();

  /// 폰에 알림 허락을 묻고 예약한다. 허락을 못 받으면 false
  Future<bool> turnOn(NoticeText text);

  /// 켜져 있으면 글만 지금 상태로 바꿔 다시 예약한다 (Pro·코인 상태가 바뀌었을 수 있다)
  Future<void> refresh(NoticeText text);

  Future<void> turnOff();
}

class PhoneNotices implements Notices {
  static const _id = 1;
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool?>? _ready;

  Future<void> _init() => _ready ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  bool get supported => !kIsWeb && Platform.isAndroid;

  @override
  Future<bool> isOn() async {
    if (!supported) return false;
    await _init();
    if (!(await _android?.areNotificationsEnabled() ?? false)) return false;
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any((p) => p.id == _id);
  }

  @override
  Future<bool> turnOn(NoticeText text) async {
    if (!supported) return false;
    await _init();
    final allowed = await _android?.requestNotificationsPermission() ?? false;
    if (!allowed) return false;
    await _schedule(text);
    return true;
  }

  @override
  Future<void> refresh(NoticeText text) async {
    if (await isOn()) await _schedule(text);
  }

  @override
  Future<void> turnOff() async {
    if (!supported) return;
    await _init();
    await _plugin.cancel(id: _id);
  }

  Future<void> _schedule(NoticeText text) async {
    // 다음 달 1일 낮 12시(이 폰 시각)를 UTC로 적고 "매달 같은 날·시각"으로 되풀이한다.
    // 시간대 자료 없이도 되고, 낮 12시라 UTC로 옮겨도 날짜가 1일에서 밀리지 않는다
    final now = DateTime.now();
    final at = tz.TZDateTime.from(
      DateTime(now.year, now.month + 1, 1, 12),
      tz.UTC,
    );
    await _plugin.zonedSchedule(
      id: _id,
      title: text.title,
      body: text.body,
      scheduledDate: at,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails('monthly', text.channel),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }
}

/// 테스트·웹: 폰 설정의 허락([allowed])을 바꿔 볼 수 있다
class DemoNotices implements Notices {
  DemoNotices({this.supported = true});

  @override
  final bool supported;
  bool allowed = true;
  NoticeText? scheduled;

  @override
  Future<bool> isOn() async => allowed && scheduled != null;

  @override
  Future<bool> turnOn(NoticeText text) async {
    if (!allowed) return false;
    scheduled = text;
    return true;
  }

  @override
  Future<void> refresh(NoticeText text) async {
    if (await isOn()) scheduled = text;
  }

  @override
  Future<void> turnOff() async => scheduled = null;
}
