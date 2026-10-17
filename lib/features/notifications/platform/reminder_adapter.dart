final class LocalReminder {
  const LocalReminder(this.id, this.at);
  final int id;
  final DateTime at;
}

abstract interface class ReminderAdapter {
  bool get supported;
  bool get schedulesWhileClosed;
  Future<bool> requestPermission();
  Future<void> show(int id, String body);
  Future<void> synchronize(List<LocalReminder> reminders, String body);
  Future<void> disable();
}
