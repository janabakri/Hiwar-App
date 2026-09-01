// تذكير يومي محلي بالإشعارات — يعمل على Android/iOS، ويتجاهل نفسه على الويب.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _enabledKey = 'hiwar_reminder_enabled';
  static const _hourKey = 'hiwar_reminder_hour';
  static const _minuteKey = 'hiwar_reminder_minute';
  static const _androidChannel = 'hiwar_daily_reminder';

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!supported) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin
        .initialize(const InitializationSettings(android: android, iOS: ios));
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// فعّل/عطّل التذكير. الوقت الافتراضي 8:00 مساءً.
  static Future<void> setEnabled(
      {required bool enabled, int hour = 20, int minute = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (!supported) return;
    if (!enabled) {
      await _plugin.cancel(0);
      return;
    }
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
    await _scheduleDaily(hour, minute);
  }

  static Future<void> _scheduleDaily(int hour, int minute) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now))
      scheduled = scheduled.add(const Duration(days: 1));
    const androidDetails = AndroidNotificationDetails(
      _androidChannel,
      'تذكير المحادثة اليومية',
      channelDescription: 'تذكيرك اليومي بممارسة الإنجليزية في حوار',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.zonedSchedule(
      0,
      'وقت محادثتك اليومية 🎙️',
      'دقيقتين بس — كمل سلسلة أيامك قبل ما تنقطع!',
      scheduled,
      const NotificationDetails(
          android: androidDetails, iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
