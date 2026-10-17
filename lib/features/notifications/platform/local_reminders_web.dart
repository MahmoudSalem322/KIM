import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'reminder_adapter.dart';

ReminderAdapter createReminderAdapter() => _BrowserReminders();

final class _BrowserReminders implements ReminderAdapter {
  @override
  bool get supported {
    try {
      return web.window.isSecureContext &&
          web.Notification.permission.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get schedulesWhileClosed => false;
  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    return (await web.Notification.requestPermission().toDart).toDart ==
        'granted';
  }

  @override
  Future<void> show(int id, String body) async {
    if (!supported || web.Notification.permission != 'granted') {
      throw StateError('Notifications are not permitted');
    }
    web.Notification(
      'Kim',
      web.NotificationOptions(body: body, tag: 'kim-$id'),
    );
  }

  @override
  Future<void> synchronize(List<LocalReminder> reminders, String body) async {}
  @override
  Future<void> disable() async {}
}
