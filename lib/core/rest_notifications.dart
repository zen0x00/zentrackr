import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class RestNotifications {
  RestNotifications._();
  static final instance = RestNotifications._();
  static const _id = 4102;
  static const _trainingIdBase = 4200;
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<void> schedule(int seconds) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    await _requestPermissions();
    await _plugin.cancel(id: _id);
    await _plugin.zonedSchedule(
      id: _id,
      title: 'Rest complete',
      body: 'Time for your next set.',
      scheduledDate: tz.TZDateTime.now(
        tz.local,
      ).add(Duration(seconds: seconds)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_timer',
          'Rest timer',
          channelDescription: 'Alerts when a workout rest period ends',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true, badge: false);
  }

  Future<void> scheduleTrainingReminders({
    required Set<int> weekdays,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    await _requestPermissions();
    await cancelTrainingReminders();
    final now = tz.TZDateTime.now(tz.local);
    for (final weekday in weekdays) {
      var date = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      final daysAhead = (weekday - date.weekday + 7) % 7;
      date = date.add(Duration(days: daysAhead));
      if (!date.isAfter(now)) date = date.add(const Duration(days: 7));
      await _plugin.zonedSchedule(
        id: _trainingIdBase + weekday,
        title: 'Time to train',
        body: 'Your next session is ready in ZenTrackr.',
        scheduledDate: date,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'training_reminders',
            'Training reminders',
            channelDescription: 'Optional reminders on your training days',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelTrainingReminders() async {
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(id: _trainingIdBase + weekday);
    }
  }

  Future<void> cancel() => _plugin.cancel(id: _id);
}
