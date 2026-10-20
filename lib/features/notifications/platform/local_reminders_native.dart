import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_adapter.dart';

ReminderAdapter createReminderAdapter() => _AndroidReminders();

final class _AndroidReminders implements ReminderAdapter {
  final plugin = FlutterLocalNotificationsPlugin();
  bool initialized = false;
  @override
  bool get supported => defaultTargetPlatform == TargetPlatform.android;
  @override
  bool get schedulesWhileClosed => supported;
  Future<void> initialize() async {
    if (initialized || !supported) return;
    data.initializeTimeZones();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification_kim'),
      ),
    );
    initialized = true;
  }

  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'kim_reminders',
      'Kim reminders',
      channelDescription: 'Private financial reminders',
      importance: Importance.defaultImportance,
      visibility: NotificationVisibility.private,
    ),
  );
  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await initialize();
    return await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  @override
  Future<void> show(int id, String body) async {
    await initialize();
    if (supported) {
      await plugin.show(
        id: id,
        title: 'Kim',
        body: body,
        notificationDetails: details,
        payload: '/notifications',
      );
    }
  }

  @override
  Future<void> synchronize(List<LocalReminder> reminders, String body) async {
    if (!supported) return;
    await initialize();
    final desired = reminders.map((r) => r.id).toSet();
    for (final pending in await plugin.pendingNotificationRequests()) {
      if (!desired.contains(pending.id)) await plugin.cancel(id: pending.id);
    }
    for (final r in reminders) {
      await plugin.zonedSchedule(
        id: r.id,
        title: 'Kim',
        body: body,
        scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '/notifications',
      );
    }
  }

  @override
  Future<void> disable() async {
    if (supported) {
      await initialize();
      await plugin.cancelAll();
    }
  }
}
