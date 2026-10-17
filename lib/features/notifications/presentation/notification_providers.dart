import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recurring/presentation/recurring_providers.dart';
import '../../budgets/presentation/budget_providers.dart';
import '../../debts/presentation/debt_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../data/local_notice_repository.dart';
import '../domain/notice.dart';
import '../platform/local_reminders.dart';
import '../platform/reminder_adapter.dart';

final noticeRepositoryProvider = Provider<LocalNoticeRepository>(
  (ref) => throw StateError('Notification repository not initialized'),
);
final noticePreferencesProvider = StreamProvider<NoticePreferences>(
  (ref) => ref.watch(noticeRepositoryProvider).watch(),
);
final reminderAdapterProvider = Provider<ReminderAdapter>(
  (ref) => createReminderAdapter(),
);
final noticesProvider = Provider<AsyncValue<List<Notice>>>((ref) {
  final plans = ref.watch(recurringPaymentsProvider),
      occurrences = ref.watch(recurringOccurrencesProvider),
      budgets = ref.watch(budgetsProvider),
      debts = ref.watch(debtsProvider),
      tx = ref.watch(transactionsProvider),
      wallets = ref.watch(walletsProvider);
  final all = <AsyncValue<Object?>>[
    plans,
    occurrences,
    budgets,
    debts,
    tx,
    wallets,
  ];
  if (all.any((s) => s.isLoading)) return const AsyncLoading();
  final error = all.where((s) => s.hasError).firstOrNull;
  if (error != null) {
    return AsyncError(error.error!, error.stackTrace ?? StackTrace.current);
  }
  return AsyncData(
    deriveNotices(
      now: ref.watch(appClockProvider)(),
      schedules: plans.requireValue,
      occurrences: occurrences.requireValue,
      budgets: budgets.requireValue,
      debts: debts.requireValue,
      transactions: tx.requireValue,
      wallets: wallets.requireValue,
    ),
  );
});
