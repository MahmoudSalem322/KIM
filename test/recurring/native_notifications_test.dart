import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kim/features/notifications/platform/local_reminders_native.dart';
import 'package:kim/features/notifications/platform/reminder_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  bool allowed = false;
  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    allowed = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'initialize':
              return true;
            case 'requestNotificationsPermission':
              return allowed;
            case 'pendingNotificationRequests':
              return [
                {
                  'id': 99,
                  'title': 'Kim',
                  'body': 'Old reminder',
                  'payload': '',
                },
              ];
            default:
              return null;
          }
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'permission denial is explicit and initialization never prompts by itself',
    () async {
      final adapter = createReminderAdapter();
      expect(adapter.supported, isTrue);
      await adapter.disable();
      expect(
        calls.any((c) => c.method == 'requestNotificationsPermission'),
        isFalse,
      );
      expect(await adapter.requestPermission(), isFalse);
      allowed = true;
      expect(await adapter.requestPermission(), isTrue);
    },
  );
  test('native reminders cancel obsolete alarms and schedule inexact generic notifications without financial data', () async {
    final adapter = createReminderAdapter();
    allowed = true;
    await adapter.requestPermission();
    await adapter.synchronize([
      LocalReminder(7, DateTime.now().add(const Duration(days: 2))),
    ], 'Open Kim to review your reminders.');
    expect(
      calls.where((c) => c.method == 'cancel').single.arguments,
      containsPair('id', 99),
    );
    final payload = Map<String, dynamic>.from(
      calls.singleWhere((c) => c.method == 'zonedSchedule').arguments as Map,
    );
    expect(payload['id'], 7);
    expect(payload['body'], 'Open Kim to review your reminders.');
    expect(payload['payload'], '/notifications');
    expect(
      payload['platformSpecifics']['scheduleMode'],
      'inexactAllowWhileIdle',
    );
  });
  test('unsupported native targets retain internal center without requesting OS permissions', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final adapter = createReminderAdapter();
    expect(adapter.supported, isFalse);
    expect(await adapter.requestPermission(), isFalse);
    expect(calls, isEmpty);
  });
}
