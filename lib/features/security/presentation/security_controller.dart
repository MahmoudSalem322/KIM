import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/security_repository.dart';

final securityRepositoryProvider = Provider<SecurityRepository?>((ref) => null);
final securityControllerProvider =
    AsyncNotifierProvider<SecurityController, SecuritySession>(
      SecurityController.new,
    );

class SecuritySession {
  const SecuritySession({required this.hasPin, required this.unlocked});
  final bool hasPin, unlocked;
}

class SecurityController extends AsyncNotifier<SecuritySession> {
  @override
  Future<SecuritySession> build() async {
    final record = await ref.watch(securityRepositoryProvider)?.load();
    return SecuritySession(hasPin: record != null, unlocked: record == null);
  }

  void lock() {
    final current = state.value;
    if (current?.hasPin == true) {
      state = const AsyncData(SecuritySession(hasPin: true, unlocked: false));
    }
  }

  Future<bool> unlock(String pin) async {
    final repo = ref.read(securityRepositoryProvider);
    if (repo == null) return false;
    final ok = await repo.verify(pin);
    if (ref.mounted && ok) {
      state = const AsyncData(SecuritySession(hasPin: true, unlocked: true));
    }
    return ok;
  }

  Future<void> configure(String pin, String? old) async {
    final repo = ref.read(securityRepositoryProvider);
    if (repo == null) throw StateError('Security unavailable');
    await repo.setPin(pin, oldPin: old);
    if (ref.mounted) {
      state = const AsyncData(SecuritySession(hasPin: true, unlocked: true));
    }
  }

  Future<void> remove(String pin) async {
    final repo = ref.read(securityRepositoryProvider);
    if (repo == null) throw StateError('Security unavailable');
    await repo.remove(pin);
    if (ref.mounted) {
      state = const AsyncData(SecuritySession(hasPin: false, unlocked: true));
    }
  }
}

final workspaceMaintenanceProvider = NotifierProvider<MaintenanceFlag, bool>(
  MaintenanceFlag.new,
);
final restoreCommittedProvider = NotifierProvider<MaintenanceFlag, bool>(
  MaintenanceFlag.new,
);
final externalFileDialogProvider = NotifierProvider<MaintenanceFlag, bool>(
  MaintenanceFlag.new,
);

class MaintenanceFlag extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) {
    if (ref.mounted) state = value;
  }
}

final reloadWorkspaceProvider = Provider<Future<void> Function()>(
  (ref) => () async {},
);
bool workspaceAccessible(WidgetRef ref) =>
    ref.read(securityControllerProvider).value?.unlocked == true &&
    !ref.read(workspaceMaintenanceProvider);
