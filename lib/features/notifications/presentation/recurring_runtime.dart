import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recurring/presentation/recurring_providers.dart';
import '../../debts/presentation/debt_providers.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/notice.dart';
import '../platform/reminder_adapter.dart';
import 'notification_providers.dart';
import '../../security/presentation/security_controller.dart';

/// Foreground/open/resume processing only. Native scheduled reminders never
/// debit wallets; financial writes always pass through the atomic processor.
class RecurringRuntime extends ConsumerStatefulWidget {
  const RecurringRuntime({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<RecurringRuntime> createState() => _RecurringRuntimeState();
}

class _RecurringRuntimeState extends ConsumerState<RecurringRuntime>
    with WidgetsBindingObserver {
  Timer? timer, debounce;
  bool syncing = false, dirty = false;
  AppLifecycleState? lifecycle;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && workspaceAccessible(ref)) {
        ref.read(processingProvider.notifier).run();
      }
    });
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted &&
          workspaceAccessible(ref) &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
        ref.invalidate(noticesProvider);
        ref.read(processingProvider.notifier).run();
        queue();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    lifecycle = state;
    if (state == AppLifecycleState.resumed && workspaceAccessible(ref)) {
      ref.invalidate(noticesProvider);
      ref.read(processingProvider.notifier).run();
      queue();
    }
  }

  void queue() {
    dirty = true;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), sync);
  }

  Future<void> sync() async {
    if (syncing || !mounted || !workspaceAccessible(ref)) return;
    syncing = true;
    dirty = false;
    try {
      final preferences = ref.read(noticePreferencesProvider),
          notices = ref.read(noticesProvider);
      if (preferences.isLoading ||
          preferences.hasError ||
          notices.isLoading ||
          notices.hasError) {
        return;
      }
      final adapter = ref.read(reminderAdapterProvider),
          repo = ref.read(noticeRepositoryProvider),
          prefs = preferences.requireValue;
      if (!prefs.enabled) {
        await adapter.disable();
        return;
      }
      final ar =
          ref.read(settingsControllerProvider).settings.languageCode == 'ar';
      // Generic text avoids leaking financial details on the lock screen.
      final body = ar
          ? 'لديك تنبيه مالي. افتح Kim لمراجعة التفاصيل.'
          : 'You have a financial reminder. Open Kim to review it.';
      for (final n
          in notices.requireValue
              .where(
                (n) =>
                    !prefs.read.contains(n.id) &&
                    !prefs.dismissed.contains(n.id),
              )
              .take(10)) {
        if (await repo.claim(n.id)) {
          try {
            await adapter.show(await repo.nativeId('notice:${n.id}'), body);
          } catch (_) {
            await repo.release(n.id);
          }
        }
      }
      final plans = ref.read(recurringPaymentsProvider),
          debts = ref.read(debtsProvider),
          wallets = ref.read(walletsProvider);
      if (plans.isLoading ||
          plans.hasError ||
          debts.isLoading ||
          debts.hasError ||
          wallets.isLoading ||
          wallets.hasError) {
        return;
      }
      final ws = {for (final w in wallets.requireValue) w.wallet.id: w},
          now = ref.read(appClockProvider)();
      final dates = reminderDates(
        now,
        plans.requireValue
            .where((p) => ws[p.draft.walletId]?.wallet.hidden == false)
            .toList(),
        debts.requireValue
            .where((d) => !d.concealed(wallets.requireValue))
            .toList(),
      );
      final reminders = <LocalReminder>[];
      for (final date in dates) {
        final d = DateTime.parse(date);
        reminders.add(
          LocalReminder(
            await repo.nativeId('day:$date'),
            DateTime(d.year, d.month, d.day, 9),
          ),
        );
      }
      await adapter.synchronize(reminders, body);
    } catch (_) {
      /* OS reminders are best effort; the internal center remains authoritative. */
    } finally {
      syncing = false;
      if (dirty && mounted) queue();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(securityControllerProvider, (previous, next) {
      if (next.value?.unlocked == true &&
          previous?.value?.unlocked != true &&
          !ref.read(workspaceMaintenanceProvider)) {
        ref.read(processingProvider.notifier).run();
        queue();
      }
    });
    ref.listen(workspaceMaintenanceProvider, (previous, next) {
      if (!next && previous == true && workspaceAccessible(ref)) {
        ref.read(processingProvider.notifier).run();
        queue();
      }
    });
    ref.listen(noticesProvider, (_, _) => queue());
    ref.listen(noticePreferencesProvider, (_, _) => queue());
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    debounce?.cancel();
    super.dispose();
  }
}
