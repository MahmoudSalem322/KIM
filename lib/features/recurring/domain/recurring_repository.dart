import '../../wallets/domain/wallet.dart';
import 'recurring_payment.dart';

abstract interface class RecurringRepository {
  Future<List<RecurringPayment>> load();
  Stream<List<RecurringPayment>> watch();
  Future<List<RecurringOccurrence>> occurrences();
  Stream<List<RecurringOccurrence>> watchOccurrences();
  Future<String> create(WalletOperation op, RecurringDraft draft);
  Future<void> edit(
    WalletOperation op,
    String id,
    int revision,
    RecurringDraft draft,
  );
  Future<void> setStatus(
    WalletOperation op,
    String id,
    int revision,
    RecurringStatus status,
  );
  Future<void> payNext(
    WalletOperation op,
    String id,
    int revision,
    DateTime now,
  );
  Future<ProcessingResult> processDue(DateTime now, {int limit = 100});
}
