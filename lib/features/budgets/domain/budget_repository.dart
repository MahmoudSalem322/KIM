import '../../wallets/domain/wallet.dart';
import 'budget.dart';

abstract interface class BudgetRepository {
  Future<List<Budget>> load();
  Stream<List<Budget>> watch();
  Future<String> create(WalletOperation op, BudgetDraft draft);
  Future<void> edit(
    WalletOperation op,
    String id,
    int revision,
    BudgetDraft draft,
  );
  Future<void> setArchived(
    WalletOperation op,
    String id,
    int revision,
    bool archived,
  );
  Future<void> delete(WalletOperation op, String id, int revision);
}
