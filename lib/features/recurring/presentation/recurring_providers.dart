import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recurring_payment.dart';
import '../domain/recurring_repository.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => throw StateError('Recurring repository not initialized'),
);
final recurringPaymentsProvider = StreamProvider<List<RecurringPayment>>(
  (ref) => ref.watch(recurringRepositoryProvider).watch(),
);
final recurringOccurrencesProvider = StreamProvider<List<RecurringOccurrence>>(
  (ref) => ref.watch(recurringRepositoryProvider).watchOccurrences(),
);
final appClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final processingProvider =
    AsyncNotifierProvider<ProcessingController, ProcessingResult?>(
      ProcessingController.new,
    );

class ProcessingController extends AsyncNotifier<ProcessingResult?> {
  bool busy = false;
  @override
  ProcessingResult? build() => null;
  Future<void> run() async {
    if (busy) return;
    busy = true;
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(recurringRepositoryProvider)
          .processDue(ref.read(appClockProvider)());
      if (ref.mounted) state = AsyncData(result);
    } catch (e, st) {
      if (ref.mounted) state = AsyncError(e, st);
    } finally {
      busy = false;
    }
  }
}
