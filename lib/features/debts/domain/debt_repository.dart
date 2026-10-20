import '../../wallets/domain/wallet.dart';
import 'debt.dart';

abstract interface class DebtRepository {
  Future<List<DebtSnapshot>> load();
  Stream<List<DebtSnapshot>> watch();
  Future<String> create(WalletOperation op, DebtDraft draft);
  Future<void> edit(
    WalletOperation op,
    String id,
    int revision,
    DebtDraft draft,
  );
  Future<String> record(
    WalletOperation op,
    String debtId,
    int debtRevision,
    DebtCashDraft draft,
    Map<String, int> wallets,
  );
  Future<void> editCash(
    WalletOperation op,
    String eventId,
    int eventRevision,
    int debtRevision,
    DebtCashDraft draft,
    Map<String, int> wallets,
  );
  Future<void> cancelCash(
    WalletOperation op,
    String eventId,
    int eventRevision,
    int debtRevision,
    Map<String, int> wallets,
  );
}
