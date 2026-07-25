import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'rest_alarm.dart';

const _kRestNotificationId = 7001;
const _kChannelId = 'htr_rest_timer';
const _kChannelName = 'Таймер отдыха';
const _kChannelDesc = 'Сигнал об окончании отдыха между подходами';

final Int64List _kVibration = Int64List.fromList([0, 400, 250, 400]);

/// Rest alert backed by an OS-scheduled local notification, so it fires even
/// when the app is backgrounded or the phone is locked. [#5/#9]
class NotificationRestAlarm implements RestAlarm {
  final FlutterLocalNotificationsPlugin _plugin;
  NotificationRestAlarm(this._plugin);

  @override
  Future<void> schedule(int seconds) async {
    if (seconds <= 0) return;
    try {
      final when =
          tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
      await _plugin.zonedSchedule(
        _kRestNotificationId,
        'Отдых окончен',
        'Пора на следующий подход 💪',
        when,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            channelDescription: _kChannelDesc,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            enableVibration: true,
            vibrationPattern: _kVibration,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Scheduling can fail if permission is denied — the in-app countdown and
      // foreground vibration still work; we just skip the locked-screen alert.
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _plugin.cancel(_kRestNotificationId);
    } catch (_) {}
  }
}

/// Initialise notifications + timezone and build a [RestAlarm]. Falls back to a
/// no-op alarm if anything goes wrong so the app always starts.
Future<RestAlarm> initRestAlarm() async {
  try {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // keep default (UTC) — countdown is relative so it still fires correctly.
    }

    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
        const InitializationSettings(android: androidInit));

    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: _kChannelDesc,
      importance: Importance.max,
      enableVibration: true,
    ));
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    return NotificationRestAlarm(plugin);
  } catch (_) {
    return const NoopRestAlarm();
  }
}
